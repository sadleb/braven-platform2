import Command from '@ckeditor/ckeditor5-core/src/command';
import uid from '@ckeditor/ckeditor5-utils/src/uid';

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
    const radioGroup = uid();
    // Value must be unique within each group, but otherwise doesn't matter.
    // No reason to tie in retained data or anything, we can just use "1".
    const radioFirstValue = '1';
    const radioFirstID = [radioGroup, radioFirstValue].join('_');

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
