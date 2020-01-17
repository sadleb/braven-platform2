import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertTextAreaCommand extends Command {
    execute( id, placeholder ) {
        this.editor.model.change( writer => {
            const textArea = createTextArea( writer, id, placeholder );
            this.editor.model.insertContent( textArea );
            writer.setSelection( textArea, 'on' );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'textArea' );

        this.isEnabled = allowedIn !== null;
    }
}

function createTextArea( writer, id, placeholder ) {
    const textArea = writer.createElement( 'textArea', { 'data-bz-retained': id, placeholder: placeholder } );
    return textArea;
}
