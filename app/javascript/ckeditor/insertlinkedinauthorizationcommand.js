import Command from '@ckeditor/ckeditor5-core/src/command';

const LINKED_IN_AUTHORIZATION_PATH = 'linked_in/login';
const PRIVACY_POLICY_URL = 'https://bebraven.org/privacy-policy/';

// The language around the LinkedIn authorization button is legally required.
const LINKED_IN_DESCRIPTION = `
Please click the following button to sign into LinkedIn and authorize Braven 
to have continued access to your profile data for an extended period of time. 
We'll use this data to track your progress towards finding a strong first job, 
so that we can support you in any way we can after you complete the course!`;
const LINKED_IN_NOTE = `
* Note: Braven won't be able to make any changes to your profile and 
will only use your data in accordance with our `; // privacy policy
// The omitted text is because we need a link, see createPrivacyPolicyParagraph.

export default class InsertLinkedInAuthorizationCommand extends Command {
    execute( host ) {
        const url = `https://${host}/${LINKED_IN_AUTHORIZATION_PATH}`;
        this.editor.model.change( writer => {
            this.editor.model.insertContent( createLinkedInAuthorization( writer, url ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent(
            selection.getFirstPosition(),
            'linkedInAuthorization',
        );

        this.isEnabled = allowedIn !== null;
    }
}

function createLinkedInAuthorization( writer, url ) {
    const container = writer.createElement( 'linkedInAuthorization' );
    writer.append( createParagraph( writer, LINKED_IN_DESCRIPTION ), container );
    writer.append( createIFrame( writer, url ), container );
    writer.append( createPrivacyPolicyParagraph( writer ), container );

    return container;
}

function createIFrame( writer, url ) {
    const iframe = writer.createElement( 'iframe', { src: url } );
    return iframe;
}

function createParagraph( writer, text ) {
    const paragraph = writer.createElement( 'paragraph' );
    writer.insertText( text, paragraph );
    return paragraph;
}

function createPrivacyPolicyParagraph( writer ) {
    const paragraph = createParagraph( writer, LINKED_IN_NOTE );
    writer.append( writer.createText( 'privacy policy', { 'linkHref': PRIVACY_POLICY_URL } ), paragraph );
    writer.append( writer.createText( '.' ), paragraph );
    return paragraph;
}
