import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { toWidget } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';

export default class ModuleBlockEditing extends Plugin {
    static get requires() {
        return [ Widget ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();
    }

    _defineSchema() {
        const schema = this.editor.model.schema;

        schema.register( 'moduleBlock', {
            isObject: true,
            allowIn: 'section',
        } );

        // Allow question, answer, and content divs inside module-block divs.
        schema.extend( 'question', {
            allowIn: [ 'moduleBlock' ],
        } );

        schema.extend( 'answer', {
            allowIn: [ 'moduleBlock' ],
        } );

        schema.extend( 'content', {
            allowIn: [ 'moduleBlock' ],
        } );
    }

    _defineConverters() {
        const editor = this.editor;
        const conversion = editor.conversion;
        const { editing, data, model } = editor;

        // <moduleBlock> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'div',
                classes: ['module-block']
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'moduleBlock', {
                    'class': viewElement.getAttribute('class') || 'module-block',
                });
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'moduleBlock',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createContainerElement( 'div', {
                    'class': modelElement.getAttribute('class') || 'module-block',
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'moduleBlock',
            view: ( modelElement, viewWriter ) => {
                const moduleBlock = viewWriter.createContainerElement( 'div', {
                    'class': modelElement.getAttribute('class') || 'module-block',
                } );

                return toWidget( moduleBlock, viewWriter, { label: 'module-block widget' } );
            }
        } );
    }
}
