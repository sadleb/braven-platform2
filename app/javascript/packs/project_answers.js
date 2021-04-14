// This JS module is used to save ProjectSubmissionAnswers entered by the user
// For an example, see the view used for project_submissions_controller#edit
import Rails from '@rails/ujs';
import { HoneycombXhrSpan } from './honeycomb'

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
    const wrapperDiv = document.getElementById(WRAPPER_DIV_ID);
    const isReadOnly = wrapperDiv.attributes[READ_ONLY_ATTR].value;
    const projectSubmissionId = wrapperDiv.attributes[SUBMISSION_DATA_ATTR].value;
    const apiUrl = `/project_submissions/${projectSubmissionId}/project_submission_answers`;

    function getAllInputs() {
        return document.querySelectorAll(SUPPORTED_INPUT_ELEMENTS.join(', '));
    }

    function getUnsavedInputs() {
        const unsaved_selectors = SUPPORTED_INPUT_ELEMENTS.map( e => `${e}.autosave-input-error` );
        return document.querySelectorAll(unsaved_selectors.join(', '));
    }

    function prefillAnswers() {

        const honeySpan = new HoneycombXhrSpan(HONEYCOMB_CONTROLLER_NAME, 'prefillAnswers', {
                                             'project_submission.id': projectSubmissionId,
                                             'readonly': isReadOnly});

        const inputs = getAllInputs();

        // Mark all inputs as disabled if data-read-only is true.
        if (isReadOnly === "true") {
            inputs.forEach((input) => {
                input.disabled = true;
            });
        }

        return fetch(
          apiUrl,
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
        getAllInputs().forEach(input => {
          input.onblur = sendAnswer;
        });
    }

    // Project autosave feedback.
    // Remove this if/when we redo in React.
    function attachInputFeedback() {
        getAllInputs().forEach(input => {
            input.insertAdjacentHTML('afterend',
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
        const lastSavedValue = input.dataset.lastSavedValue;

        // Exit if the value hasn't changed from the last saved one.
        if (lastSavedValue && input.value == lastSavedValue) return;

        // Ignore it if they clicked into an empty field and did nothing.
        // Note that we want them to be able to clear out old values, so if
        // something was already saved then send the empty value.
        if (!lastSavedValue && !input.value) return;

        const inputName = input.name;
        const inputValue = input.value;
        const inputAlert = input.nextElementSibling; // div.autosave-alert

        // Display saving indicator.
        changeAutoSaveStatus('Saving...', 'autosave-status-saving');

        const data = {
            project_submission_answer: {
                input_name: inputName,
                input_value: inputValue,
            },
        };

        const honeySpan = new HoneycombXhrSpan(HONEYCOMB_CONTROLLER_NAME, 'sendAnswer', {
                                             'project_submission.id': projectSubmissionId,
                                             'readonly': isReadOnly,
                                             'input_name': inputName,
                                             'input_value': inputValue});

         // AJAX call to ProjectSubmissionAnswersController.
        fetch(
          apiUrl,
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
            // User feedback.
            input.classList.remove('autosave-input-error');
            input.dataset.lastSavedValue = input.value;
            inputAlert.innerHTML = "";
            if (getUnsavedInputs().length === 0) {
                changeAutoSaveStatus('All progress saved.', 'autosave-status-success');
                projectSubmitButtion.toggleEnabled(true);
            } else {
                projectSubmitButtion.toggleEnabled(false);
                changeAutoSaveStatus('Some answers are still unsaved! Look for those that say "Failed to save answer." and click Retry.', 'autosave-status-error');
            }

            // Logging.
            honeySpan.addField('response.status', response.status, false);
        })
        .catch((error) => {
            projectSubmitButtion.toggleEnabled(false);

            // User feedback.
            input.classList.add('autosave-input-error');
            inputAlert.innerHTML = "Failed to save answer. <a href='#'>Retry?</a>";
            inputAlert.querySelector('a').onclick = () => { 
                // clicking the Retry on any of the failed answers retries them all
                getUnsavedInputs().forEach((unsavedInput) => {
                    unsavedInput.dispatchEvent(new Event('blur'));
                });
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
    if (projectSubmissionId) {
        await prefillAnswers();
    }

    // If write-enabled, attach listeners to save intermediate responses
    if (isReadOnly === "false") {
        attachInputListeners();
        attachInputFeedback();
    }
}

document.addEventListener('DOMContentLoaded', main);
