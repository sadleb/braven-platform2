import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { enablePlaceholder } from '@ckeditor/ckeditor5-engine/src/view/placeholder';
import { toWidget, toWidgetEditable } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';
import InsertTextInputCommand from './inserttextinputcommand';
import InsertDoneButtonCommand from './insertdonebuttoncommand';

export default class ContentBlockEditing extends Plugin {
    static get requires() {
        return [ Widget ];
    }

    init() {
        this.setupContentBlockEditing('Flush');
        this.setupContentBlockEditing('Key');
        this.setupContentBlockEditing('Alert');
        this.setupContentBlockEditing('Tip');
        this.setupContentBlockEditing('Pulse');
        this.setupContentBlockEditing('Action');
        this.setupContentBlockEditing('Reflection');
        this.setupContentBlockEditing('Read');
    }

    setupContentBlockEditing(blockType) {
        const editor = this.editor;
        const schema = editor.model.schema;
        const conversion = editor.conversion;
        const { editing, data, model } = editor;

        const blockTypeLower = blockType.toLowerCase();
        const blockTypeContent = `${blockTypeLower}Content`;

        // schema
        schema.extend( 'content', {
            allowIn: [ blockTypeContent ],
        });
        schema.extend( 'question', {
            allowIn: [ blockTypeContent ],
        });

        schema.register( blockTypeContent, {
            isObject: true,
            allowIn: 'section',
        } );

        // converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'div',
                classes: ['module-block', `module-block-${blockTypeLower}`]
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( blockTypeContent );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: blockTypeContent,
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createEditableElement( 'div', {
                    'class': `module-block module-block-${blockTypeLower}`,
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: blockTypeContent,
            view: ( modelElement, viewWriter ) => {
                const div = viewWriter.createContainerElement( 'div', {
                    'class': `module-block module-block-${blockTypeLower}`,
                } );

                return toWidget( div, viewWriter, { label: `${blockTypeLower} widget` } );
            }
        } );
    }
}
