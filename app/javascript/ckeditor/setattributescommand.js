import Command from '@ckeditor/ckeditor5-core/src/command';

export default class SetAttributesCommand extends Command {
    execute( attributes ) {
        this.editor.model.change( writer => {
            const selectedElement = this.editor.model.document.selection.getSelectedElement();
            writer.setAttributes( attributes, selectedElement );
        } );
    }

    refresh() {
        this.isEnabled = true;
    }
}
