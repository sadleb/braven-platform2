import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { toWidget, toWidgetEditable } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';
import InsertIFrameContentCommand from './insertiframecontentcommand';

export default class IFrameContentEditing extends Plugin {
    static get requires() {
        return [ Widget ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();

        this.editor.commands.add( 'insertIFrameContent', new InsertIFrameContentCommand( this.editor ) );
    }

    _defineSchema() {
        const schema = this.editor.model.schema;

        schema.register( 'iframeContent', {
            isObject: true,
            allowIn: 'section',
            allowAttributes: [ 'id', 'class' ]
        } );

        schema.register( 'iframe', {
            allowIn: 'content',
            allowAttributes: [ 'src' ]
        } );
    }

    _defineConverters() {
        const editor = this.editor;
        const conversion = editor.conversion;
        const { editing, data, model } = editor;

        // <iframeContent> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'div',
                classes: ['module-block', 'module-iframe']
            },
            model: ( viewElement, modelWriter ) => {
                // Read the "data-id" attribute from the view and set it as the "id" in the model.
                return modelWriter.createElement( 'iframeContent', {
                    id: parseInt( viewElement.getAttribute( 'data-id' ) )
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'iframeContent',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createEditableElement( 'div', {
                    'class': 'module-block module-iframe',
                    'data-id': modelElement.getAttribute( 'id' )
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'iframeContent',
            view: ( modelElement, viewWriter ) => {
                const id = modelElement.getAttribute( 'id' );

                const iframeContent = viewWriter.createContainerElement( 'div', {
                    'class': 'module-block module-iframe',
                    'data-id': id
                } );

                return toWidget( iframeContent, viewWriter, { label: 'iframe widget' } );
            }
        } );

        // <iframe> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'iframe',
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'iframe', {
                    'src': viewElement.getAttribute( 'src' )
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'iframe',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createEditableElement( 'iframe', {
                    'src': modelElement.getAttribute( 'src' )
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'iframe',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createEditableElement( 'iframe', {
                    'src': modelElement.getAttribute( 'src' )
                } );
            }
        } );
    }
}
