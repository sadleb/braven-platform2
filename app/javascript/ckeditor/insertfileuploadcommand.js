import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertFileUploadCommand extends Command {
    execute() {
        this.editor.model.change( writer => {
            this.editor.model.insertContent( createFileUpload( writer ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'fileUpload' );

        this.isEnabled = allowedIn !== null;
    }
}

function createFileUpload( writer ) {
    const fileUpload = writer.createElement( 'fileUpload' );
    return fileUpload;
}
