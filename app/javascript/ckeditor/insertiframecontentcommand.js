import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertIFrameContentCommand extends Command {
    execute( url ) {
        this.editor.model.change( writer => {
            this.editor.model.insertContent( createIFrameContent( writer, url ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'moduleBlock' );

        this.isEnabled = allowedIn !== null;
    }
}

function createIFrameContent( writer, url ) {
    const iframeContent = writer.createElement( 'moduleBlock' );
    const content = writer.createElement( 'content' );
    const contentTitle = writer.createElement( 'contentTitle' );
    const contentBody = writer.createElement( 'contentBody' );
    const iframe = writer.createElement( 'iframe', {src: url} );

    const contentParagraph = writer.createElement( 'paragraph' );

    writer.append( content, iframeContent );
    writer.append( contentTitle, content );
    writer.append( contentBody, content );
    writer.append( iframe, content );

    // There must be at least one paragraph for the description to be editable.
    // See https://github.com/ckeditor/ckeditor5/issues/1464.
    writer.append( contentParagraph, contentBody );

    return iframeContent;
}
