import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import SetAttributesCommand from './setattributescommand';
import RemoveAttributeCommand from './removeattributecommand';

export default class AttributeEditing extends Plugin {
    static get pluginName() {
        return 'AttributeEditing';
    }

    init() {
        this.editor.commands.add( 'setAttributes', new SetAttributesCommand( this.editor ) );
        this.editor.commands.add( 'removeAttribute', new RemoveAttributeCommand( this.editor ) );
    }
}
