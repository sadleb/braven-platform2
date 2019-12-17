import Command from '@ckeditor/ckeditor5-core/src/command';
import { findOptimalInsertionPosition } from '@ckeditor/ckeditor5-widget/src/utils';

export default class InsertMatchingQuestionCommand extends Command {
    execute( id ) {
		const model = this.editor.model;
		const selection = model.document.selection;
		const tableUtils = this.editor.plugins.get( 'TableUtils' );

		const rows = 2;
		const columns = 2;

		//const insertPosition = findOptimalInsertionPosition( selection, model );

        this.editor.model.change( writer => {
            // Insert <matchingQuestion id="...">*</matchingQuestion> at the current selection position
            // in a way which will result in creating a valid model structure.

    const matchingQuestion = writer.createElement( 'matchingQuestion', {id} );
    const question = writer.createElement( 'question' );
    const questionTitle = writer.createElement( 'questionTitle' );
    const matchingTable = writer.createElement( 'matchingTable' );
    const matchingTableBody = writer.createElement( 'matchingTableBody' );
    const matchingTableRow1 = writer.createElement( 'matchingTableRow' );
    const matchingTableRow2 = writer.createElement( 'matchingTableRow' );
    const matchingTableCell11 = writer.createElement( 'matchingTableCell' );
    const matchingTableCell12 = writer.createElement( 'matchingTableCell' );
    const matchingTableCell21 = writer.createElement( 'matchingTableCell' );
    const matchingTableCell22 = writer.createElement( 'matchingTableCell' );


    writer.append( question, matchingQuestion );
    writer.append( questionTitle, question );
    writer.append( matchingTable, question );
    writer.append( matchingTableBody, matchingTable );
    writer.append( matchingTableRow1, matchingTableBody );
    writer.append( matchingTableRow2, matchingTableBody );
    writer.append( matchingTableCell11, matchingTableRow1 );
    writer.append( matchingTableCell12, matchingTableRow1 );
    writer.append( matchingTableCell21, matchingTableRow2 );
    writer.append( matchingTableCell22, matchingTableRow2 );

    // Add text to empty editables, to get around the lack of placeholder support.
    writer.insertText( 'Question?', questionTitle );
    writer.insertText( '11', matchingTableCell11 );
    writer.insertText( '12', matchingTableCell12 );
    writer.insertText( '21', matchingTableCell21 );
    writer.insertText( '22', matchingTableCell22 );

            model.insertContent( matchingQuestion );
	    //writer.setSelection( writer.createPositionAt( table.getNodeByPath( [ 0, 0, 0 ] ), 0 ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'matchingQuestion' );

        this.isEnabled = allowedIn !== null;
    }
}
