import Command from '@ckeditor/ckeditor5-core/src/command';

export default class SetAttributesCommand extends Command {
    execute( attributes, element = undefined ) {
        this.editor.model.change( writer => {
            const selectedElement = this.editor.model.document.selection.getSelectedElement();
            writer.setAttributes( attributes, element || selectedElement );
        } );
    }

    refresh() {
        this.isEnabled = true;
    }
}
