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
    const api_url = `/project_submissions/${projectSubmissionId}/project_submission_answers`;

    function getAllInputs() {
        return document.querySelectorAll(SUPPORTED_INPUT_ELEMENTS.join(', '));   
    }
    
    function prefillAnswers() {

        const honey_span = new HoneycombXhrSpan(HONEYCOMB_CONTROLLER_NAME, 'prefillAnswers', {
                                             'submission.id': projectSubmissionId,
                                             'url': api_url,
                                             'readonly': isReadOnly});
    
        const inputs = getAllInputs();
    
        // Mark all inputs as disabled if data-read-only is true.
        if (isReadOnly === "true") {
            inputs.forEach((input) => {
                input.disabled = true;
            });
        }    
    
        return fetch(
          api_url,
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
                    map[obj.input_name] = obj.input_value;
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
                });
            });
    
        })
        .catch((error) => {
            const error_msg = 'Failed to populate previous answers.';
            console.error(error_msg);
            honey_span.addErrorDetails(error_msg, error);
        });
    }
    
    function attachInputListeners() {
        getAllInputs().forEach(input => { input.onblur = sendAnswer });
    }
    
    function sendAnswer(e) {
        const input = e.target;
        const input_name = input.name;
        const input_value = input.value;
     
        const data = {
            project_submission_answer: {
                input_name: input_name,
                input_value: input_value,
            },
        };
    
        const honey_span = new HoneycombXhrSpan(HONEYCOMB_CONTROLLER_NAME, 'sendAnswer', {
                                             'submission.id': projectSubmissionId,
                                             'url': api_url,
                                             'readonly': isReadOnly,
                                             'input.name': input_name,
                                             'input.value': input_value});

         // AJAX call to ProjectSubmissionAnswersController.
        fetch(
          api_url,
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
            honey_span.addField('response.status', response.status);
        })
        .catch((error) => {
            const error_msg = `Failed to save answer: [name='${input_name}', value='${input_value}']`;
            console.error(error_msg);
            honey_span.addErrorDetails(error_msg, error);
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
    }
}

document.addEventListener('DOMContentLoaded', main);
