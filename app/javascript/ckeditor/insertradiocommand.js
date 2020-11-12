import Command from '@ckeditor/ckeditor5-core/src/command';
import { findAllowedParentIgnoreLimit, getNamedAncestor } from './utils';
import uid from '@ckeditor/ckeditor5-utils/src/uid';

export default class InsertRadioCommand extends Command {
    execute() {
        this.editor.model.change( writer => {
            // Before inserting, modify the current selection to after the radioDiv.
            const selection = this.editor.model.document.selection;
            const selectedElement = selection.getSelectedElement();
            const position = selection.getFirstPosition();

            // Find the radioDiv.
            let radioDiv;
            if ( selectedElement && selectedElement.name === 'radioDiv' ) {
                // The current selection is a radioDiv.
                radioDiv = selectedElement;
            } else if ( [ 'radioLabel', 'radioInlineFeedback' ].includes(position.parent.name) ) {
                // The cursor is inside one of the elements in the radioDiv, so find its ancestor radioDiv.
                radioDiv = getNamedAncestor( 'radioDiv', position );
            } else {
                // In any other case, just return without doing anything.
                // This makes us a bit more robust, in case we modify radioDiv later on.
                return;
            }

            writer.setSelection( radioDiv, 'after' );
            this.editor.model.insertContent( createRadio(
                writer,
                radioDiv.parent.getAttribute( 'data-radio-group' ),
            ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;

        // Explicitly ignore Limit behavior, because radioLabel is a limit.
        // This feels hacky, but should be safe here.
        const allowedIn = findAllowedParentIgnoreLimit( model.schema, selection.getFirstPosition(), 'radioDiv' );

        this.isEnabled = allowedIn !== null;
    }
}

function createRadio( writer, name ) {
    const value = uid();
    const id = [name, value].join('_');

    const radioDiv = writer.createElement( 'radioDiv' );
    const radioInput = writer.createElement( 'radioInput', {
        name: name,
        id: id,
        value: value,
    } );
    const radioLabel = writer.createElement( 'radioLabel', { 
        'for': id,
    } );

    writer.append( radioInput, radioDiv );
    writer.append( radioLabel, radioDiv );

    // Add text to empty editables where placeholders don't work.
    writer.insertText( 'Radio label', radioLabel );

    return radioDiv;
}
