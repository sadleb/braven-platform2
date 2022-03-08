// This JS module is used to save ProjectSubmissionAnswers entered by the user
// For an example, see the view used for project_submissions_controller#edit
import Rails from '@rails/ujs';
import { HoneycombXhrSpan, HoneycombAddToSpan } from './honeycomb'

const AUTH_HEADER = 'LtiState '+ document.querySelector('meta[name="state"]').content;
const HONEYCOMB_CONTROLLER_NAME = 'project_answers';

// Passed in from the view using this JS
const SUBMISSION_DATA_ATTR = 'data-project-submission-id';
const READ_ONLY_ATTR = 'data-read-only';
const WRAPPER_DIV_ID = 'custom-content-wrapper';

// These are the HTML elements we'll attach sendAnswer() to
const SUPPORTED_INPUT_ELEMENTS = [
 'input[type="radio"]',
 'input[type="text"]',
 'select',
 'textarea',
];

export async function main() {
    // Send an event at the top of main so we know main is getting called.
    const manualHoneySpan = new HoneycombAddToSpan('project_answers', 'main');
    manualHoneySpan.addField('run', true);
    manualHoneySpan.sendNow();

    const wrapperDiv = document.getElementById(WRAPPER_DIV_ID);
    const isReadOnly = wrapperDiv.attributes[READ_ONLY_ATTR].value;

    function getProjectSubmissionId() {
        // Half-React hack: Read the submission ID from the div every time we need it,
        // in case the ProjectSubmitButton React component changed the ProjectSubmission
        // out from under us (which it does every time you submit).
        return wrapperDiv.attributes[SUBMISSION_DATA_ATTR].value;
    }

    function getApiUrl() {
        return `/project_submissions/${getProjectSubmissionId()}/project_submission_answers`;
    }

    function getAllInputs() {
        return document.querySelectorAll(SUPPORTED_INPUT_ELEMENTS.join(', '));
    }

    function getUnsavedInputs() {
        const unsaved_selectors = SUPPORTED_INPUT_ELEMENTS.map(e =>
            `${e}.autosave-input-error, .autosave-input-error ${e}`
        );
        return document.querySelectorAll(unsaved_selectors.join(', '));
    }

    function prefillAnswers() {

        const honeySpan = new HoneycombXhrSpan(HONEYCOMB_CONTROLLER_NAME, 'prefillAnswers', {
                                             'project_submission.id': getProjectSubmissionId(),
                                             'readonly': isReadOnly});

        const inputs = getAllInputs();

        // Mark all inputs as disabled if data-read-only is true.
        if (isReadOnly === "true") {
            inputs.forEach((input) => {
                input.disabled = true;
            });
        }

        return fetch(
          getApiUrl(),
          {
            method: 'GET',
            headers: {
              'Content-Type': 'application/json;charset=utf-8',
              'Authorization': AUTH_HEADER
            },
          },
         )
        .then((response) => {
            // Convert array of answer objects into map of {input_name: input_value}.
            response.json().then((answers) => {
                const prefills = answers.reduce((map, obj) => {
                    map[obj.input_name] = obj.input_value; // Ruby snake_case sent
                    return map;
                }, {});

                inputs.forEach( input => {
                    // Prefill input values with answers.
                    const prefill = prefills[input.name];
                    if (!prefill) {
                        return; // Nothing previously entered by user.
                    } else if (input.type == 'radio') {
                        if (input.value == prefill) {
                            input.checked = true; // Check appropriate radio.
                        }
                    } else {
                        input.value = prefill; // Set input value.
                    }
                    input.dataset.lastSavedValue = prefill;
                });
            });

        })
        .catch((error) => {
            const errorMsg = 'Failed to populate previous answers.';
            console.error(errorMsg);
            honeySpan.addErrorDetails(errorMsg, error);
        });
    }

    function attachInputListeners() {
        const inputs = getAllInputs();
        const honeySpan = new HoneycombAddToSpan('project_answers', 'attachInputListeners');
        honeySpan.addField('inputs.count', inputs.length);

        inputs.forEach(input => {
          input.onchange = sendAnswer;
        });
    }

    // Project autosave feedback.
    // Remove this if/when we redo in React.
    function attachInputFeedback() {
        const inputs = getAllInputs();
        const honeySpan = new HoneycombAddToSpan('project_answers', 'attachInputFeedback');
        honeySpan.addField('inputs.count', inputs.length);

        inputs.forEach(input => {
            var element;
            if (input.type === "radio") {
                // For radio buttons, put the alert div after the label.
                element = input.parentElement.querySelector('label');
            } else {
                // For other input types, put the alert immediately after the input.
                element = input;
            }
            element.insertAdjacentHTML('afterend',
                '<div class="autosave-alert" role="alert" aria-live="polite"></div>'
            );
        });
    }

    function changeAutoSaveStatus(text, cssClass) {
        const statusBar = document.getElementById('autosave-status-bar');
        statusBar.textContent = text;
        statusBar.classList = cssClass;
    }

    function sendAnswer(e) {
        const input = e.target;
        // The "question target" is an element representing a single question,
        // on which error classes, last saved values, etc can be set. Most of
        // the time, this is the input itself, but for radios, it's the
        // fieldset ancestor.
        const questionTarget = input.type === "radio" ?
            input.closest('fieldset') : input;
        const lastSavedValue = input.dataset.lastSavedValue;

        const inputName = input.name;
        const inputValue = input.value;
        // Alert div is the next sibling on most inputs, but is placed after
        // the label for radio inputs.
        const inputAlert = input.type === "radio" ?
            input.parentElement.querySelector('div.autosave-alert') :
            input.nextElementSibling;

        // Display saving indicator.
        changeAutoSaveStatus('Saving...', 'autosave-status-saving');

        const data = {
            project_submission_answer: {
                input_name: inputName,
                input_value: inputValue,
            },
        };

        const honeySpan = new HoneycombXhrSpan(HONEYCOMB_CONTROLLER_NAME, 'sendAnswer', {
                                             'project_submission.id': getProjectSubmissionId(),
                                             'readonly': isReadOnly,
                                             'input_name': inputName,
                                             'input_value': inputValue});

         // AJAX call to ProjectSubmissionAnswersController.
        fetch(
          getApiUrl(),
          {
            method: 'POST',
            body: JSON.stringify(data),
            headers: {
              'X-CSRF-Token': Rails.csrfToken(),
              'Content-Type': 'application/json;charset=utf-8',
              'Authorization': AUTH_HEADER
            },
          },
         )
        .then((response) => {
            // Logging.
            honeySpan.addField('response.status', response.status, false);

            // Error handling.
            if (!response.ok) {
                // 4xx and 5xx responses should procede to the .catch below.
                throw new Error(`HTTP Response ${response.status}`);
            }

            // User feedback.
            questionTarget.classList.remove('autosave-input-error');
            questionTarget.dataset.lastSavedValue = input.value;
            inputAlert.innerHTML = "";
            if (getUnsavedInputs().length === 0) {
                changeAutoSaveStatus('All progress saved.', 'autosave-status-success');
                projectSubmitButton.toggleEnabled(true);
                honeySpan.addField('unsaved_inputs', false);
            } else {
                projectSubmitButton.toggleEnabled(false);
                changeAutoSaveStatus('Some answers are still unsaved! Look for those that say "Failed to save answer." and click Retry.', 'autosave-status-error');
                honeySpan.addField('unsaved_inputs', true);
            }
        })
        .catch((error) => {
            projectSubmitButton.toggleEnabled(false);

            // User feedback.
            questionTarget.classList.add('autosave-input-error');
            inputAlert.innerHTML = "Failed to save answer. <a href='#'>Retry?</a>";
            inputAlert.querySelector('a').onclick = () => { 
                // clicking the Retry on any of the failed answers retries them all
                const inputs = getUnsavedInputs();
                inputs.forEach((unsavedInput) => {
                    unsavedInput.dispatchEvent(new Event('change'));
                });
                honeySpan.addField('unsaved_inputs.count', inputs.length);
            }
            changeAutoSaveStatus("Answers failed to save! Check your internet connection. You will lose your work if you continue.", 'autosave-status-error');

            // Logging.
            const errorMsg = `Failed to save answer: [name='${inputName}', value='${inputValue}']`;
            console.error(errorMsg);
            honeySpan.addErrorDetails(errorMsg, error);
        });
    }

    /////////////////////////////
    // Main page logic.
    /////////////////////////////

    // If no answers have been saved in the past, there won't be a submission or anything to pre-fill.
    if (getProjectSubmissionId()) {
        await prefillAnswers();
    }

    // If write-enabled, attach listeners to save intermediate responses
    if (isReadOnly === "false") {
        attachInputListeners();
        attachInputFeedback();
    }
}

document.addEventListener('DOMContentLoaded', main);

const getOneSupportedElement = () => {
    // return the first text input.
    return document.querySelector(SUPPORTED_INPUT_ELEMENTS[1]);
};

// Send an event outside of main so we know the JS is running at all.
const honeySpan = new HoneycombAddToSpan('project_answers', 'script');
honeySpan.addField('run', true);
honeySpan.sendNow();

/*
 * Commenting this out for now so we can collect data more reliably
 * on who's encountering this.

['storage', 'popstate'].forEach(eventName => {
    window.addEventListener(eventName, (event) => {
        if(getOneSupportedElement().onchange === null) {
            const msg = `issue detected; repairing with on${eventName} strategy...`;
            const honeySpan = new HoneycombAddToSpan('project_answers', 'script');
            honeySpan.addField('repair_message', msg);
            console.log(msg);
            honeySpan.sendNow();
            main();
        }
    });
});
*/
[2000, 5000, 10000].forEach(delay => {
    setTimeout(() => {
        if(getOneSupportedElement().onchange === null) {
            const msg = `issue detected; repairing with setTimeout(${delay}) strategy...`;
            const honeySpan = new HoneycombAddToSpan('project_answers', 'script');
            honeySpan.addField('repair_message', msg);
            console.log(msg);
            honeySpan.sendNow();
            main();
        }
    }, delay);
});
