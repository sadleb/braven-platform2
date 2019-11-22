import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertCheckboxCommand extends Command {
    execute( id ) {
        this.editor.model.change( writer => {
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
