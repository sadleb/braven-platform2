import Command from '@ckeditor/ckeditor5-core/src/command';
import UniqueId from './uniqueid';

export default class InsertRadioQuestionCommand extends Command {
    execute() {
        this.editor.model.change( writer => {
            this.editor.model.insertContent( createRadioQuestion( writer ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'questionFieldset' );

        this.isEnabled = allowedIn !== null;
    }
}

function createRadioQuestion( writer ) {
    // Get unique IDs for radio group/name, value, and ID.
    const uniqueId = new UniqueId();
    const radioGroup = uniqueId.getNewName();
    const radioFirstValue = uniqueId.getNewValue();
    const radioFirstID = uniqueId.getNewId();

    const questionFieldset = writer.createElement( 'questionFieldset', {'data-radio-group': radioGroup} );
    const radioDiv = writer.createElement( 'radioDiv' );
    const radioInput = writer.createElement( 'radioInput', {
        name: radioGroup,
        id: radioFirstID,
        value: radioFirstValue,
    } );
    const radioLabel = writer.createElement( 'radioLabel', { 'for': radioFirstID } );

    writer.append( radioDiv, questionFieldset );
    writer.append( radioInput, radioDiv );
    writer.append( radioLabel, radioDiv );

    // Add text to empty editables where placeholders don't work.
    writer.insertText( 'Radio label', radioLabel );

    return questionFieldset;
}
