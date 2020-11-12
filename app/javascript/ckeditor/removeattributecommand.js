import Command from '@ckeditor/ckeditor5-core/src/command';

export default class RemoveAttributeCommand extends Command {
    execute( attribute, element = undefined ) {
        this.editor.model.change( writer => {
            const selectedElement = this.editor.model.document.selection.getSelectedElement();
            writer.removeAttribute( attribute, element || selectedElement );
        } );
    }

    refresh() {
        this.isEnabled = true;
    }
}
