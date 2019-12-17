import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertRadioCommand extends Command {
    execute( id ) {
        this.editor.model.change( writer => {
            // NOTE: We're making a huge assumption here that we'll only ever call this command while
            // the current selection is *inside* a radio label. If that ever changes, we'll need to
            // add some extra logic here.
            // Before inserting, modify the current selection to after the radioDiv (the grandparent
            // of the current selection, iff the aforementioned assumption holds true).
            writer.setSelection( this.editor.model.document.selection.focus.parent.parent, 'after' );
            this.editor.model.insertContent( createRadio( writer, id ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'radioDiv' );

        this.isEnabled = allowedIn !== null;
    }
}

function createRadio( writer, id ) {
    const radioDiv = writer.createElement( 'radioDiv' , {id} );
    const radioInput = writer.createElement( 'radioInput' );
    const radioLabel = writer.createElement( 'radioLabel' );

    writer.append( radioInput, radioDiv );
    writer.append( radioLabel, radioDiv );

    return radioDiv;
}
