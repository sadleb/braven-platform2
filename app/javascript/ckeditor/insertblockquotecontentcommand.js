import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertBlockquoteContentCommand extends Command {
    execute( id ) {
        this.editor.model.change( writer => {
            // Insert <blockquoteContent id="...">*</blockquoteContent> at the current selection position
            // in a way which will result in creating a valid model structure.
            this.editor.model.insertContent( createBlockquoteContent( writer, id ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'blockquoteContent' );

        this.isEnabled = allowedIn !== null;
    }
}

function createBlockquoteContent( writer, id ) {
    const blockquoteContent = writer.createElement( 'blockquoteContent', {id} );
    const content = writer.createElement( 'content' );
    const quote = writer.createElement( 'blockquoteQuote' );
    const paragraph = writer.createElement( 'paragraph' );
    const citation = writer.createElement( 'blockquoteCitation' );

    writer.append( content, blockquoteContent );
    writer.append( quote, content );
    writer.append( paragraph, quote );
    writer.append( citation, quote );

    // Add text to empty editables, to get around the lack of placeholder support.
    // There must be at least one paragraph for the description to be editable.
    // See https://github.com/ckeditor/ckeditor5/issues/1464.
    writer.insertText( 'Quote', paragraph );
    writer.insertText( 'Citation', citation );

    return blockquoteContent;
}
