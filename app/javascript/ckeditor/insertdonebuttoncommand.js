import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertDoneButtonCommand extends Command {
    execute( id ) {
        this.editor.model.change( writer => {
            const doneButton = createDoneButton( writer, id );
            this.editor.model.insertContent( doneButton );
            writer.setSelection( doneButton, 'on' );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'doneButton' );

        this.isEnabled = allowedIn !== null;
    }
}

function createDoneButton( writer, id ) {
    const doneButton = writer.createElement( 'doneButton', { 'data-bz-retained': id } );
    return doneButton;
}
