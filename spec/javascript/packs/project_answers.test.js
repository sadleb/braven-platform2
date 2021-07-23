import fetchMock from "jest-fetch-mock";
fetchMock.enableMocks();

beforeEach(() => {
  fetch.resetMocks();
});

/*
beforeEach(() => {
    // Set up our document 
    document.head.innerHTML = '<meta name="state" content="test">';
    document.body.innerHTML =
        '<input type="text" name="test-id">' +
        '<textarea name="test-id-2"></textarea>' +
        '<fieldset>' +  // start radio group
        '<div class="custom-content-radio-div">' +
        '<input type="radio" value="radio-value-1" name="radio-group-1">' +
        '</div>' +
        '<div class="custom-content-radio-div">' +
        '<input type="radio" value="radio-value-2" name="radio-group-1">' +
        '</div>' +
        '</fieldset>' +  // end radio group
        '<select name="select-1">' +  // start dropdown
        '<option value="">&nbsp;</option>' +
        '<option value="1">1</option>' +
        '</select>';  // end dropdown
});
*/

function setupHtml(projectSubmissionId, readOnly, innerHtml){
    document.head.innerHTML = '<meta name="state" content="test">';
    document.body.innerHTML =
        '<div class="container bv-lti-container">' +
          '<div class="bv-custom-content-container" id="custom-content-wrapper"' +
             `data-read-only="${readOnly}" data-project-submission-id="${projectSubmissionId}">` +
            innerHtml +
          '</div>' +
        '</div>';
}

test('prefills text input answers', async () => {
    const projectSubmissionId = 33;
    const answerId = 44;
    const inputName = 'content-name-1234';
    const inputValue = 'fellow typed something';
    setupHtml(projectSubmissionId, false, `<input type="text" name="${inputName}">`);

    // Mock the `fetch` response.
    fetch.mockResponseOnce(JSON.stringify([
        {id: answerId, project_submission_id: projectSubmissionId, input_name: inputName, input_value: inputValue}
    ]));

    const project_answers = require('packs/project_answers');
    await project_answers.main();

    expect(fetch).toHaveBeenCalledTimes(1);
    expect(document.querySelector(`input[name='${inputName}']`).value).toBe(inputValue);
});

test('prefills textarea answers', async () => {
    const projectSubmissionId = 33;
    const answerId = 44;
    const inputName = 'content-name-1234';
    const inputValue = 'fellow typed something';
    setupHtml(projectSubmissionId, false, `<textarea name="${inputName}"></textarea>`);

    // Mock the `fetch` response.
    fetch.mockResponseOnce(JSON.stringify([
        {id: answerId, project_submission_id: projectSubmissionId, input_name: inputName, input_value: inputValue}
    ]));

    const project_answers = require('packs/project_answers');
    await project_answers.main();

    expect(fetch).toHaveBeenCalledTimes(1);
    expect(document.querySelector(`textarea[name='${inputName}']`).value).toBe(inputValue);
});

test('prefills radio answers', async () => {
    const projectSubmissionId = 33;
    const answerId = 44;
    const inputName = 'content-name-1234';
    const inputValue = 'radio-value-2';
    setupHtml(projectSubmissionId, false, `
        <fieldset>
          <div class="custom-content-radio-div">
            <input type="radio" value="radio-value-1" name="${inputName}" id="radio-1">
            <label for="radio-1">one</label>
          </div>
          <div class="custom-content-radio-div">
            <input type="radio" value="radio-value-2" name="${inputName}" id="radio-2">
            <label for="radio-2">two</label>
          </div>
        </fieldset>
    `);

    // Mock the `fetch` response.
    fetch.mockResponseOnce(JSON.stringify([
        {id: answerId, project_submission_id: projectSubmissionId, input_name: inputName, input_value: inputValue}
    ]));

    const project_answers = require('packs/project_answers');
    await project_answers.main();

    expect(fetch).toHaveBeenCalledTimes(1);
    expect(document.querySelector(`input[value='radio-value-1']`).checked).toBe(false);
    expect(document.querySelector(`input[value='radio-value-2']`).checked).toBe(true);
});

test('prefills dropdown answers', async () => {
    const projectSubmissionId = 33;
    const answerId = 44;
    const inputName = 'content-name-1234';
    const inputValue = '2';
    setupHtml(projectSubmissionId, false, `
        <select name="${inputName}">
          <option value="">&nbsp;</option>
          <option value="1">1</option>
          <option value="2">2</option>
          <option value="3">3</option>
        </select>
    `);

    // Mock the `fetch` response.
    fetch.mockResponseOnce(JSON.stringify([
        {id: answerId, project_submission_id: projectSubmissionId, input_name: inputName, input_value: inputValue}
    ]));

    const project_answers = require('packs/project_answers');
    await project_answers.main();

    expect(fetch).toHaveBeenCalledTimes(1);
    expect(document.querySelector(`select[name='${inputName}']`).value).toBe(inputValue);
});

test('inputs are set to read-only in TA view', async () => {
    const projectSubmissionId = 33;
    const answerId = 44;
    const inputName = 'test-id';
    const inputValue = '2';
    // Set up our document for TA view.
    setupHtml(projectSubmissionId, true, `
        <input type="text" name="${inputName}">
        <textarea name="test-id-2"></textarea>
    `);

    // Mock the `fetch` response.
    fetch.mockResponseOnce(JSON.stringify([
        {id: answerId, project_submission_id: projectSubmissionId, input_name: inputName, input_value: inputValue}
    ]));

    const project_answers = require('packs/project_answers');
    await project_answers.main();

    expect(fetch).toHaveBeenCalledTimes(1);
    expect(document.body.querySelector(`[name="${inputName}"]`).disabled).toBe(true);
    expect(document.body.querySelector('[name="test-id-2"]').disabled).toBe(true);
});
