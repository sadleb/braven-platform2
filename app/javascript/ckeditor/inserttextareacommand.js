import Command from '@ckeditor/ckeditor5-core/src/command';
import UniqueId from './uniqueid';

export default class InsertTextAreaCommand extends Command {
    execute( ) {
        this.editor.model.change( writer => {
            const textArea = createTextArea( writer );
            this.editor.model.insertContent( textArea );
            writer.setSelection( textArea, 'on' );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'textArea' );

        this.isEnabled = allowedIn !== null;
    }
}

function createTextArea( writer ) {
    const uniqueId = new UniqueId();
    const textArea = writer.createElement( 'textArea', {
        'name': uniqueId.getNewName(),
    } );
    return textArea;
}
