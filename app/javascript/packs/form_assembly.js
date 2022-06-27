// This is responsible for any customization we have to do to the Form Assembly
// using Javascript b/c there is no other way to do it. Try to avoid doing this!
//
// Run this script by adding
//  <%= javascript_pack_tag 'form_assembly', 'data-turbolinks-track': 'reload' %>
// to the head of your layout.

import { HoneycombAddToSpan } from './honeycomb'

export async function main() {

  // The built-in behavior for Form Assembly e-Signature forms is that on the final
  // page where you sign, it shows a warning message saying:
  //
  // Incomplete Response
  // Please click the link in the verification email to complete your signature.
  //
  // However, you don't get the email until after you click the button to submit.
  // This is confusing. The JS below changes the message to be more clear.
  async function changeESignatureMessage() {
    const honeySpan = new HoneycombAddToSpan('form_assembly', 'changeESignatureMessage');
    try {
      let esigWarning = document.querySelector('fieldset#tfa_esignature-email-warning');
      if (esigWarning) {
        honeySpan.addField('esignature_message_found', 'true');

        let esigWarningLegend = esigWarning.querySelector('legend.errMsg');
        esigWarningLegend.innerHTML = '<i class="fa fa-envelope" aria-hidden="true"></i> Next step';
        let esigWarningMsg = esigWarning.querySelector('div.errMsg');
        esigWarningMsg.innerText = 'Immediately check your email and spam for a link to verify the forms you just signed ' +
                                   'after submitting the signed response below.';

        honeySpan.addField('esignature_message_changed', 'true');
      } else {
        honeySpan.addField('esignature_message_found', 'false');
      }
    } catch (err) {
      const errorMsg = 'Failed to customize the e-Signature warning message to be more clear what should be done after submitting.';
      honeySpan.addErrorDetails(error_msg, err);
    }
  }

  changeESignatureMessage();

} // END: main

window.onload = main;
