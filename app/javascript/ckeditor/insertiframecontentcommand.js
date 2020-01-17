import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertIFrameContentCommand extends Command {
    execute( id, url ) {
        this.editor.model.change( writer => {
            // Insert <iframeContent id="...">*</iframeContent> at the current selection position
            // in a way which will result in creating a valid model structure.
            this.editor.model.insertContent( createIFrameContent( writer, id, url ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'iframeContent' );

        this.isEnabled = allowedIn !== null;
    }
}

function createIFrameContent( writer, id, url ) {
    const iframeContent = writer.createElement( 'iframeContent', {id} );
    const content = writer.createElement( 'content' );
    const iframe = writer.createElement( 'iframe', {src: url} );

    writer.append( content, iframeContent );
    writer.append( iframe, content );

    return iframeContent;
}
