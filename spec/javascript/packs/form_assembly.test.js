/**
 * @jest-environment jsdom
 */

import { HoneycombAddToSpan } from 'packs/honeycomb'
jest.mock('packs/honeycomb');

beforeEach(() => {
  // Clear all instances and calls to constructor and all methods:
  HoneycombAddToSpan.mockClear();
});

function setupHtml(esigwarningHtml = ''){
  document.body.innerHTML = `
    <form action="https://form.assembly.url/responses/processor" method="POST">
      <h3>Your Signature</h3>
      <fieldset id="tfa_esignature" class="section">
        <legend id="tfa_esignature-L">Please sign here</legend>
        <div class="wFormsSignature">
          here is where the signature is with a bunch of inputs
        </div>
      </fieldset>
      ${esigwarningHtml}
      <div class="reviewActions actions">
        <input type="submit" class="primaryAction slds-button slds-button--brand full-width" value="Submit Signed Response">
      </div>
    </form>`
}

test('changes the message when found', async () => {
  let validESignatureWarningHtml = `
    <style>
    #tfa_esignature-email-warning {
        padding: 16px 16px 20px 16px;
    }
  </style>
  <fieldset id="tfa_esignature-email-warning" class="section errFld">
      <legend id="tfa_esignature-email-warning-L" class="errMsg"><i class="fa fa-envelope" aria-hidden="true"></i> Incomplete Response</legend>
      <div class="errMsg">
          Please click the link in the verification email to complete your signature.    </div>
  </fieldset>`

  setupHtml(validESignatureWarningHtml);

  const formAssembly = require('packs/form_assembly');
  await formAssembly.main();

  expect(document.querySelector('#tfa_esignature-email-warning legend.errMsg').innerHTML)
    .toBe('<i class="fa fa-envelope" aria-hidden="true"></i> Next step');

  expect(document.querySelector('#tfa_esignature-email-warning div.errMsg').innerText)
    .toBe('Immediately check your email and spam for a link to verify the forms you just signed after submitting the signed response below.');
});


test('NOOP when not found', async () => {
  let nonESignatureWarningHtml = '<div id="tfa_1-E" class="errMsg" tabindex="-1"><span>This field is required.</span></div>';
  setupHtml(nonESignatureWarningHtml);

  const formAssembly = require('packs/form_assembly');
  await formAssembly.main();

  expect(document.querySelector('#tfa_1-E').innerHTML)
    .toBe('<span>This field is required.</span>');

  expect(HoneycombAddToSpan).toHaveBeenCalled();
  const mockHoneycombSpan = HoneycombAddToSpan.mock.instances[0];
  const mockAddErrorDetails = mockHoneycombSpan.addErrorDetails;
  expect(mockAddErrorDetails).not.toHaveBeenCalled();
});
