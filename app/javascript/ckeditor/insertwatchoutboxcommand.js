import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertWatchOutBoxCommand extends Command {
    execute() {
        this.editor.model.change( writer => {
            const watchOutBoxContainer = createWatchOutBoxContainer( writer );
            this.editor.model.insertContent( watchOutBoxContainer );
            // Set the selection inside the watchOutBox.
            writer.setSelection( watchOutBoxContainer.getChild(0), 'in' );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'watchOutBoxContainer' );

        this.isEnabled = allowedIn !== null;
    }
}

function createWatchOutBoxContainer( writer ) {
    const watchOutBoxContainer = writer.createElement( 'watchOutBoxContainer' );
    const watchOutBox = writer.createElement( 'watchOutBox' );
    // There must be at least one paragraph for the element to be editable.
    // See https://github.com/ckeditor/ckeditor5/issues/1464.
    writer.appendElement( 'paragraph', watchOutBox );
    writer.append( watchOutBox, watchOutBoxContainer );
    return watchOutBoxContainer;
}
