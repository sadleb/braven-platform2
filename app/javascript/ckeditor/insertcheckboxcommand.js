import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertCheckboxCommand extends Command {
    execute( id ) {
        this.editor.model.change( writer => {
            // NOTE: We're making a huge assumption here that we'll only ever call this command while
            // the current selection is *inside* a checkbox label. If that ever changes, we'll need to
            // add some extra logic here.
            // Before inserting, modify the current selection to after the checkboxDiv (the grandparent
            // of the current selection, iff the aforementioned assumption holds true).
            writer.setSelection( this.editor.model.document.selection.focus.parent.parent, 'after' );
            this.editor.model.insertContent( createCheckbox( writer, id ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'checkboxDiv' );

        this.isEnabled = allowedIn !== null;
    }
}

function createCheckbox( writer, id ) {
    const checkboxDiv = writer.createElement( 'checkboxDiv' , {id} );
    const checkboxInput = writer.createElement( 'checkboxInput' );
    const checkboxLabel = writer.createElement( 'checkboxLabel' );

    writer.append( checkboxInput, checkboxDiv );
    writer.append( checkboxLabel, checkboxDiv );

    return checkboxDiv;
}
