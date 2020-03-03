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
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'iframeContent' );

        this.isEnabled = allowedIn !== null;
    }
}

function createIFrameContent( writer, url ) {
    const iframeContent = writer.createElement( 'iframeContent' );
    const content = writer.createElement( 'content' );
    const iframe = writer.createElement( 'iframe', {src: url} );

    writer.append( content, iframeContent );
    writer.append( iframe, content );

    return iframeContent;
}
