import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertRadioCommand extends Command {
    execute( id ) {
    alert("omg its actually executing");
        this.editor.model.change( writer => {
            // Insert <radioDiv id="...">*</radioDiv> at the current selection position
            // in a way which will result in creating a valid model structure.
            this.editor.model.insertContent( createRadio( writer, id ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        console.log(selection);
        console.log(selection.getFirstPosition());
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'radioDiv' );

        this.isEnabled = allowedIn !== null;
        console.log('--------insertradiocommand refresh');
        console.log(this.isEnabled);
    }
}

function createRadio( writer, id ) {
    const radioDiv = writer.createElement( 'radioDiv' );
    const radioInput = writer.createElement( 'radioInput' );
    const radioLabel = writer.createElement( 'radioLabel' );

    writer.append( radioInput, radioDiv );
    writer.append( radioLabel, radioDiv );

    // There must be at least one paragraph for the description to be editable.
    // See https://github.com/ckeditor/ckeditor5/issues/1464.
    //writer.appendElement( 'paragraph', answerText );

    return radioDiv;
}
