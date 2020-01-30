import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertTextInputCommand extends Command {
    execute( placeholder ) {
        this.editor.model.change( writer => {
            const textInput = createTextInput( writer, placeholder );
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

function createTextInput( writer, placeholder ) {
    const textInput = writer.createElement( 'textInput', {placeholder} );
    return textInput;
}
