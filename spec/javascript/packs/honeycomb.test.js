/**
 * @jest-environment jsdom
 */

beforeEach(() => {
    window.BOOMR = {
        plugins: { Errors: { send: jest.fn() } },
        isBoomerangLoaded: true,
        hasSentPageLoadBeacon: jest.fn(),
        subscribe: jest.fn(),
        addVar: jest.fn(),
        now: jest.fn(),
        responseEnd: jest.fn()
    };
});

test('HoneycombXhrSpan adds standard fields to span', () => {

    window.BOOMR.hasSentPageLoadBeacon.mockReturnValue(true);
    const honeycomb = require('packs/honeycomb.js');

    const honey_span = new honeycomb.HoneycombXhrSpan('the_filename', 'the_function_name', {'somefield': 'somevalue'});
    expect(window.BOOMR.addVar.mock.calls.length).toBe(1);
    expect(window.BOOMR.addVar.mock.calls[0][0]).toBe('js.app.the_filename.the_function_name.somefield');
    expect(window.BOOMR.addVar.mock.calls[0][1]).toBe('somevalue');
    expect(window.BOOMR.addVar.mock.calls[0][2]).toBe(true);

});

test('HoneycombAddToSpan adds fields after Boomerang loaded', () => {
    delete window.BOOMR.isBoomerangLoaded;
    const honeycomb = require('packs/honeycomb.js');

    const honey_span = new honeycomb.HoneycombAddToSpan('the_filename', 'the_function_name', {'somefield': 'somevalue'});
    expect(window.BOOMR.addVar.mock.calls.length).toBe(0);

    window.BOOMR.isBoomerangLoaded = true;
    document.dispatchEvent(new Event('onBoomerangLoaded'));
    expect(window.BOOMR.addVar.mock.calls.length).toBe(1);
});

test('HoneycombXhrSpan adds fields after Boomerang loaded', () => {
    delete window.BOOMR.isBoomerangLoaded;
    const honeycomb = require('packs/honeycomb.js');

    const honey_span = new honeycomb.HoneycombXhrSpan('the_filename', 'the_function_name', {'somefield': 'somevalue'});
    expect(window.BOOMR.addVar.mock.calls.length).toBe(0);

    window.BOOMR.hasSentPageLoadBeacon = jest.fn().mockReturnValue(true);
    window.BOOMR.isBoomerangLoaded = true;
    document.dispatchEvent(new Event('onBoomerangLoaded'));
    expect(window.BOOMR.addVar.mock.calls.length).toBe(1);
});

// Mimic Boomerang having been initialized but not having sent the page load beacon
test('HoneycombXhrSpan adds fields after page load beacon', () => {

    // Save the callback function it subscribes to when page_load_beacon event happens.
    var pageLoadBeaconCallback = null;
    window.BOOMR.subscribe.mockImplementation((eventName, callbackFn) => pageLoadBeaconCallback = callbackFn);
    window.BOOMR.hasSentPageLoadBeacon.mockReturnValue(false);
    const honeycomb = require('packs/honeycomb.js');

    const honey_span = new honeycomb.HoneycombXhrSpan('the_filename', 'the_function_name', {'somefield': 'somevalue'});
    expect(window.BOOMR.addVar.mock.calls.length).toBe(0);

    // Mimic the page load beacon having happened and the callback executed.
    window.BOOMR.hasSentPageLoadBeacon.mockReturnValue(true);
    pageLoadBeaconCallback();

    expect(window.BOOMR.addVar.mock.calls.length).toBe(1);
});

test('HoneycombXhrSpan adds multiple fields', () => {
    window.BOOMR.hasSentPageLoadBeacon.mockReturnValue(true);
    const honeycomb = require('packs/honeycomb.js');

    const honey_span = new honeycomb.HoneycombXhrSpan('the_filename', 'the_function_name');
    window.BOOMR.addVar.mockClear();

    honey_span.addFields({ 'field1': 'value1', 'field2': 'value2'});
    expect(window.BOOMR.addVar.mock.calls.length).toBe(2);
    expect(window.BOOMR.addVar.mock.calls[0][0]).toBe('js.app.the_filename.the_function_name.field1');
    expect(window.BOOMR.addVar.mock.calls[0][1]).toBe('value1');
    expect(window.BOOMR.addVar.mock.calls[0][2]).toBe(true);
    expect(window.BOOMR.addVar.mock.calls[1][0]).toBe('js.app.the_filename.the_function_name.field2');
    expect(window.BOOMR.addVar.mock.calls[1][1]).toBe('value2');
    expect(window.BOOMR.addVar.mock.calls[1][2]).toBe(true);

});

test('HoneycombXhrSpan can add fields with no prefix', () => {
    window.BOOMR.hasSentPageLoadBeacon.mockReturnValue(true);
    const honeycomb = require('packs/honeycomb.js');

    const honey_span = new honeycomb.HoneycombXhrSpan('the_filename', 'the_function_name');
    window.BOOMR.addVar.mockClear();

    honey_span.addField('field1', 'value1', false);
    expect(window.BOOMR.addVar.mock.calls.length).toBe(1);
    expect(window.BOOMR.addVar.mock.calls[0][0]).toBe('js.app.field1');
    expect(window.BOOMR.addVar.mock.calls[0][1]).toBe('value1');
    expect(window.BOOMR.addVar.mock.calls[0][2]).toBe(true);

});

test('HoneycombXhrSpan sends errors now with standard details when string', () => {
    window.BOOMR.hasSentPageLoadBeacon.mockReturnValue(true);
    const honeycomb = require('packs/honeycomb.js');

    const honey_span = new honeycomb.HoneycombXhrSpan('the_filename', 'the_function_name');
    window.BOOMR.addVar.mockClear();

    honey_span.addErrorDetails('some message', 'someError');
    expect(window.BOOMR.addVar.mock.calls.length).toBe(1);
    expect(window.BOOMR.addVar.mock.calls[0][0]['error']).toBe('Error');
    expect(window.BOOMR.addVar.mock.calls[0][0]['error_log']).toBe('some message');
    expect(window.BOOMR.addVar.mock.calls[0][0]['error_filename']).toBe('the_filename');
    expect(window.BOOMR.addVar.mock.calls[0][0]['error_function']).toBe('the_function_name');
    expect(window.BOOMR.addVar.mock.calls[0][0]['error_detail']).toContain('someError');
    expect(window.BOOMR.addVar.mock.calls[0][0]['error_stacktrace']).toContain('honeycomb.js'); // Top of the stack, created from the string within honeycomb.js
    expect(window.BOOMR.plugins.Errors.send.mock.calls.length).toBe(1);
});

test('HoneycombXhrSpan sends errors now with standard details when Error object', () => {
    window.BOOMR.hasSentPageLoadBeacon.mockReturnValue(true);
    const honeycomb = require('packs/honeycomb.js');

    const honey_span = new honeycomb.HoneycombXhrSpan('the_filename2', 'the_function_name2');
    window.BOOMR.addVar.mockClear();

    honey_span.addErrorDetails('some message2', new Error('someError2'));
    expect(window.BOOMR.addVar.mock.calls.length).toBe(1);
    expect(window.BOOMR.addVar.mock.calls[0][0]['error']).toBe('Error');
    expect(window.BOOMR.addVar.mock.calls[0][0]['error_log']).toBe('some message2');
    expect(window.BOOMR.addVar.mock.calls[0][0]['error_filename']).toBe('the_filename2');
    expect(window.BOOMR.addVar.mock.calls[0][0]['error_function']).toBe('the_function_name2');
    expect(window.BOOMR.addVar.mock.calls[0][0]['error_detail']).toContain('someError2');
    expect(window.BOOMR.addVar.mock.calls[0][0]['error_stacktrace']).toContain('honeycomb.test.js'); // Top of the stack, I just created it.
    expect(window.BOOMR.plugins.Errors.send.mock.calls.length).toBe(1);
});

test('HoneycombAddToSpan sends errors now with standard details when Error object', () => {
    window.BOOMR.hasSentPageLoadBeacon.mockReturnValue(true);
    const honeycomb = require('packs/honeycomb.js');

    const honey_span = new honeycomb.HoneycombAddToSpan('the_filename3', 'the_function_name3');
    window.BOOMR.addVar.mockClear();

    honey_span.addErrorDetails('some message3', new Error('someError3'));
    expect(window.BOOMR.addVar.mock.calls.length).toBe(1);
    expect(window.BOOMR.addVar.mock.calls[0][0]['error']).toBe('Error');
    expect(window.BOOMR.addVar.mock.calls[0][0]['error_log']).toBe('some message3');
    expect(window.BOOMR.addVar.mock.calls[0][0]['error_filename']).toBe('the_filename3');
    expect(window.BOOMR.addVar.mock.calls[0][0]['error_function']).toBe('the_function_name3');
    expect(window.BOOMR.addVar.mock.calls[0][0]['error_detail']).toContain('someError3');
    expect(window.BOOMR.addVar.mock.calls[0][0]['error_stacktrace']).toContain('honeycomb.test.js'); // Top of the stack, I just created it.
    expect(window.BOOMR.plugins.Errors.send.mock.calls.length).toBe(1);
});

test('sendNow() calls responseEnd() with the context to force the beacon to be sent', () => {
    window.BOOMR.hasSentPageLoadBeacon.mockReturnValue(true);
    const startTime = Date.now();
    window.BOOMR.now.mockReturnValue(startTime);
    const honeycomb = require('packs/honeycomb.js');

    const honey_span = new honeycomb.HoneycombXhrSpan('the_filename4', 'the_function_name4');
    window.BOOMR.addVar.mockClear();

    honey_span.sendNow();
    expect(window.BOOMR.responseEnd.mock.calls.length).toBe(1);
    expect(window.BOOMR.responseEnd.mock.calls[0][0]).toBe('js.app.the_filename4.the_function_name4');
    expect(window.BOOMR.responseEnd.mock.calls[0][1]).toBe(startTime);
});
