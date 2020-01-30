import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertRadioCommand extends Command {
    execute() {
        this.editor.model.change( writer => {
            // NOTE: We're making a huge assumption here that we'll only ever call this command while
            // the current selection is *inside* a radio label. If that ever changes, we'll need to
            // add some extra logic here.
            // Before inserting, modify the current selection to after the radioDiv (the grandparent
            // of the current selection, iff the aforementioned assumption holds true).
            const grandparentRadioDiv = this.editor.model.document.selection.focus.parent.parent;
            writer.setSelection( grandparentRadioDiv, 'after' );
            this.editor.model.insertContent( createRadio( writer ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'radioDiv' );

        this.isEnabled = allowedIn !== null;
    }
}

function createRadio( writer ) {
    const radioDiv = writer.createElement( 'radioDiv' );
    const radioInput = writer.createElement( 'radioInput' );
    const radioLabel = writer.createElement( 'radioLabel' );
    const radioInlineFeedback = writer.createElement( 'radioInlineFeedback' );

    writer.append( radioInput, radioDiv );
    writer.append( radioLabel, radioDiv );
    writer.append( radioInlineFeedback, radioDiv );

    // Add text to empty editables where placeholders don't work.
    writer.insertText( 'Radio label', radioLabel );


    return radioDiv;
}
