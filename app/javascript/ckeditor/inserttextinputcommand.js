import Command from '@ckeditor/ckeditor5-core/src/command';
import UniqueId from './uniqueid';

export default class InsertTextInputCommand extends Command {
    execute( ) {
        this.editor.model.change( writer => {
            const textInput = createTextInput( writer );
            this.editor.model.insertContent( textInput );
            writer.setSelection( textInput, 'on' );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'textInput' );

        this.isEnabled = allowedIn !== null;
    }
}

function createTextInput( writer ) {
    const uniqueId = new UniqueId();
    const textInput = writer.createElement( 'textInput', {
        'name': uniqueId.getNewName(),
        'placeholder': '',
        'aria-label': '',
    } );
    return textInput;
}
