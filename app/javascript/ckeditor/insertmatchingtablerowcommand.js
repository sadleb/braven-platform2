import Command from '@ckeditor/ckeditor5-core/src/command';
import { findOptimalInsertionPosition } from '@ckeditor/ckeditor5-widget/src/utils';

export default class InsertMatchingTableRow extends Command {
    execute( id ) {
		const model = this.editor.model;
		const selection = model.document.selection;
		const tableUtils = this.editor.plugins.get( 'TableUtils' );


        this.editor.model.change( writer => {
            // NOTE: We're making a huge assumption here that we'll only ever call this command while
            // the current selection is *inside* a table cell. If that ever changes, we'll need to
            // add some extra logic here.
            // Before inserting, modify the current selection to after the checkboxRow (the grandparent
            // of the current selection, iff the aforementioned assumption holds true).
            writer.setSelection( this.editor.model.document.selection.focus.parent.parent, 'after' );

    const matchingTableRow = writer.createElement( 'matchingTableRow' );
    const matchingTableCell1 = writer.createElement( 'matchingTableCell' );
    const matchingTableCell2 = writer.createElement( 'matchingTableCell' );
    const matchingTableCell3 = writer.createElement( 'matchingTableCell' );


    writer.append( matchingTableCell1, matchingTableRow );
    writer.append( matchingTableCell2, matchingTableRow );
    writer.append( matchingTableCell3, matchingTableRow );

    // Add text to empty editables, to get around the lack of placeholder support.
    writer.insertText( 'Title', matchingTableCell1 );
    writer.insertText( 'Text', matchingTableCell2 );
    writer.insertText( 'Text', matchingTableCell3 );

            model.insertContent( matchingTableRow );
	    //writer.setSelection( writer.createPositionAt( table.getNodeByPath( [ 0, 0, 0 ] ), 0 ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'matchingTableRow' );

        this.isEnabled = allowedIn !== null;
    }
}
