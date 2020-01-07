import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertTextAreaCommand extends Command {
    execute( id ) {
        this.editor.model.change( writer => {
            this.editor.model.insertContent( createTextArea( writer, id ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'textArea' );

        this.isEnabled = allowedIn !== null;
    }
}

function createTextArea( writer, id ) {
    const textAreaDiv = writer.createElement( 'textArea' );
    return textAreaDiv;
}
