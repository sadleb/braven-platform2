import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertTableCommand extends Command {
    execute( id, options = {} ) {
        const model = this.editor.model;
        const selection = model.document.selection;
        const tableUtils = this.editor.plugins.get( 'TableUtils' );

        const rows = parseInt( options.rows ) || 2;
        const columns = parseInt( options.columns ) || 2;

        this.editor.model.change( writer => {
            // Insert <tableContent id="...">*</tableContent> at the current selection position
            // in a way which will result in creating a valid model structure.

            const tableContent = writer.createElement( 'tableContent', {id} );
            const content = writer.createElement( 'content' );

            writer.append(content, tableContent);

            model.insertContent( tableContent );
            writer.setSelection( writer.createPositionAt( content, 0 ) );
            this.editor.execute( 'insertTable', { rows: rows, columns: columns } );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'tableContent' );

        this.isEnabled = allowedIn !== null;
    }
}
