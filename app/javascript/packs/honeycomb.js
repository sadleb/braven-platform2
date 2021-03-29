import { isErrorObject } from '../utils/errorutils';

const FIELD_PREFIX = 'js.app';

/*
 * Base class for various types of span wrappers exported in this module.
 */
class HoneycombSpanBase {

    /*
     * Instantiate this with a particular "fileName" and "functionName".
     *
     * @param {Function} functionWrapper a function that takes a function as an argument and wraps it in
     *                                   extra logic before (and after) executing it. All public methods
     *                                   will be wrapped in this if it's specified.
     */
    constructor(fileName, functionName, fields = {}, functionWrapper = null) {
        this.fileName = fileName;
        this.functionName = functionName;
        this.context = `${fileName}.${functionName}`;
        this.functionWrapper = functionWrapper;

        this.getFieldName = function(key, prefixWithContext = true) {
            if (prefixWithContext) {
                return `${FIELD_PREFIX}.${this.context}.${key}`
            } else {
                return `${FIELD_PREFIX}.${key}`
            }
        }

        this.runAfterBoomerangLoaded = function(f) {
            if (window.BOOMR && window.BOOMR.isBoomerangLoaded) {
                if (functionWrapper) {
                    functionWrapper(f);
                } else {
                    f();
                }
            } else {
                // In the real world, this should only fire once, but in jest tests it can be fired multiple times. Hence the "once" option.
                document.addEventListener("onBoomerangLoaded", () => this.runAfterBoomerangLoaded(f), { once: true });
            }
        }

        this.runAfterBoomerangLoaded(() => {
            // Fields that the caller passed into the constructor
            this.addFields(fields);

            this.startTime = window.BOOMR.now();
        });
    }

    /*
     * Adds a field to the current span. Note that field names are prefixed by the "context"
     * of this span, so just add the "interesting_thing_name" you want as the key and not
     * where to look in the code according to the field naming guidelines on the Wiki
     *
     * Set prefixWithContext to false if you're adding a generic field that is not specific to
     * JS file/context.
     */
    addField(key, value, prefixWithContext = true) {
        this.runAfterBoomerangLoaded(() => {
            window.BOOMR.addVar(this.getFieldName(key, prefixWithContext), value, true);
        });
    }

    /*
     * Adds multiple fields to the current span. See addField() for a note about field naming
     * and the prefixWithContext param.
     */
    addFields(fields, prefixWithContext = true) {
        this.runAfterBoomerangLoaded(() => {
            for (const key of Object.keys(fields)) {
                this.addField(key, fields[key], prefixWithContext);
            }
        });
    }

    /*
     * Adds a standard Error object to the current span and sends the beacon immediately.
     *
     * Most errors will be picked up and logged automatically, but not with the easiest to read and
     * query for data. This pulls out some convenient details from the error and adds them as fields.
     *
     * If you don't explicitly catch errors and call this, the fields that will come through are
     * are found here: https://github.com/bebraven/boomerang/blob/master/plugins/zzz-last-plugin.js#L22
     * so make sure that these fields match those, otherwise you'll have the same error information
     * in different fields
     */
    addErrorDetails(log_msg, e) {
        this.runAfterBoomerangLoaded(() => {
             // Some things, like the LRS.saveStatement() calls, don't send actual error objects so we
             // can't get the stacktrace, etc. Artificially create an Error object so the stacktrace is there.
             if (isErrorObject(e) == false) { e = new Error(JSON.stringify(e)) }

             // Don't prefix these field names, they're standard.
             const error_data = {
                 error: e.name,
                 error_log: log_msg,
                 error_detail: e.toString(),
                 error_filename: this.fileName,
                 error_function: this.functionName,
                 error_stacktrace: e.stack
             };
             window.BOOMR.addVar(error_data, null, true);
             window.BOOMR.plugins.Errors.send(e); // Force the beacon to go out.
        });
    }

    /*
     * When measuring arbitrary events, call this to force a beacon to go out with
     * any fields you added and the h.pg field set to the context of this span with the
     * time it took to run as the value.
     * See here for more detail: https://akamai.github.io/boomerang/tutorial-howto-measure-arbitrary-events.html
     */
    sendNow() {
        this.runAfterBoomerangLoaded(() => {
            if(this.startTime) {
                window.BOOMR.responseEnd(`${FIELD_PREFIX}.${this.context}`, this.startTime);
            }
        });
    }
}

/*
 * Wrapper for Boomerang AutoXHR plugin beacons (also handles Fetch requests) to treat them
 * as a "span" in Honeycomb. This allows us to more easily add our own instrumentation details
 * to what the automatic beacon provides and ensure that it ends up on the correct beacon.
 * See here for documentation on the AutoXHR plugin behavior:
 *     https://akamai.github.io/boomerang/BOOMR.plugins.AutoXHR.html
 *
 * Note: use snake_case for field names to keep things consistent with the Rails instrumentation.
 * The one exception is the functionName b/c that should be an actual JS function which is CamelCase

 * Example Usage:
 * const honeySpan = new HoneycombXhrSpan('file_name', 'function_name', {
 *    'some_field1_to_add': 'value1',
 *    'some_field2_to_add': 'value2'});
 *
 * try {
 *
 * ... kick off XHR or Fetch request ...
 *
 *     honeySpan.addField('another_field_to_add', 'value2');
 *
 * } catch(err) {
 *     honeySpan.honeySpan.addErrorDetails('error message about what happened', err);
 * }
 *
 * That's it! The span info will automatically go out in the XHR beacon.
 *
 * Note: for XHR/Fetch requests that start during page load, the AutoXHR plugin will capture the timing
 * information, but this wrapper ensures that the instrumentation we add goes in the XHR beacon
 * that is sent after the page load beacon. This whole concept of the page load beacon is very
 * important to understand when dealing with Boomerang.
 *
 * Note2: if you enhance this class, try to avoid translating built-in Boomerang fields (aka vars)
 * into normalized ones that we use for Rails instrumentation. Let the honeycombjs_controller do the
 * translation when possible.
 */
export class HoneycombXhrSpan extends HoneycombSpanBase {

    /*
     * See the base class for info on the params.
     *
     * Another way to think about the "functionName" HoneycombXhrSpan is that it's the AJAX call we're making,
     * which may have callbacks and other function's to accomplish it, but all instrumentation added
     * in those should be part of the overall request/response.
     */
    constructor(fileName, functionName, fields = {}) {
      // Define a wrapper function that delays executing the passed in function until the page load beacon has
      // gone out. Pass this to the base class so that it wraps all public methods with this delay.
      // We need to do this so that the fields end up in the XHR beacon and not the page load beacon so they
      // end up in that Honeycomb span and don't get split across multiple.
      const runAfterPageLoadBeacon = function(f) {
          if (window.BOOMR.hasSentPageLoadBeacon()) {
              f();
          } else {
              window.BOOMR.subscribe("page_load_beacon", () => runAfterPageLoadBeacon(f), { once: true } );
          }
      };

      super(fileName, functionName, fields, runAfterPageLoadBeacon);
    }
}

/*
 * Wrapper for adding extra instrumentation to any Boomerang beacon so that it will go into the corresponding
 * Honeycomb span once the beacon is sent. This can be used to add fields to the page load beacon, or
 * log errors during page load.
 *
 * Note: use snake_case for field names to keep things consistent with the Rails instrumentation.
 * The one exception is the functionName b/c that should be an actual JS function which is CamelCase
 *
 * Example Usage:
 * const honeySpan = new HoneycombAddToSpan('file_name', 'functionName');
 * try {
 *     ... something not necessarily related to an Ajax call using XHR or Fetch, like initializing a component ...
 *     honeySpan.addField('key_name_of_something_interesting', 'interesting_value');
 * } catch (err) {
 *     const errorMsg = "something went wrong";
 *     honeySpan.addErrorDetails(errorMsg, err);
 * }
 */
export class HoneycombAddToSpan extends HoneycombSpanBase {

    constructor(fileName, functionName, fields = {}) {
      super(fileName, functionName, fields);
    }

}
