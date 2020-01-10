import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertSectionCommand extends Command {
    execute( id ) {
        this.editor.model.change( writer => {
            this.editor.model.insertContent( createSection( writer, id ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'section' );

        this.isEnabled = allowedIn !== null;
    }
}

function createSection( writer, id ) {
    const section = writer.createElement( 'section',  {id} );

    // There must be at least one paragraph for the section to be editable.
    // See https://github.com/ckeditor/ckeditor5/issues/1464.
    writer.appendElement( 'paragraph', section );

    return section;
}
