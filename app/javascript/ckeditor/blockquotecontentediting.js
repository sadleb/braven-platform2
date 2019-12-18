import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { toWidget, toWidgetEditable } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';
import InsertBlockquoteContentCommand from './insertblockquotecontentcommand';

export default class BlockquoteContentEditing extends Plugin {
    static get requires() {
        return [ Widget ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();

        this.editor.commands.add( 'insertBlockquoteContent', new InsertBlockquoteContentCommand( this.editor ) );
    }

    _defineSchema() {
        const schema = this.editor.model.schema;

        schema.register( 'blockquoteContent', {
            isObject: true,
            allowIn: 'section',
            allowAttributes: [ 'id', 'class' ]
        } );

        schema.register( 'blockquoteQuote', {
            allowIn: 'content',
            allowContentOf: '$root'
        } );

        schema.register( 'blockquoteCitation', {
            allowIn: 'blockquoteQuote',
            allowContentOf: '$block'
        } );
    }

    _defineConverters() {
        const editor = this.editor;
        const conversion = editor.conversion;
        const { editing, data, model } = editor;

        // <blockquoteContent> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'div',
                classes: ['module-block', 'module-block-quote']
            },
            model: ( viewElement, modelWriter ) => {
                // Read the "data-id" attribute from the view and set it as the "id" in the model.
                return modelWriter.createElement( 'blockquoteContent', {
                    id: parseInt( viewElement.getAttribute( 'data-id' ) )
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'blockquoteContent',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createEditableElement( 'div', {
                    'class': 'module-block module-block-quote',
                    'data-id': modelElement.getAttribute( 'id' )
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'blockquoteContent',
            view: ( modelElement, viewWriter ) => {
                const id = modelElement.getAttribute( 'id' );

                const blockquoteContent = viewWriter.createContainerElement( 'div', {
                    'class': 'module-block module-block-quote',
                    'data-id': id
                } );

                return toWidget( blockquoteContent, viewWriter, { label: 'blockquote widget' } );
            }
        } );

        // <blockquoteQuote> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'blockquoteQuote',
            view: {
                name: 'blockquote'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'blockquoteQuote',
            view: {
                name: 'blockquote'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'blockquoteQuote',
            view: ( modelElement, viewWriter ) => {
                const blockquote = viewWriter.createEditableElement( 'blockquote' );

                return toWidgetEditable( blockquote, viewWriter );
            }
        } );

        // <blockquoteCitation> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'blockquoteCitation',
            view: {
                name: 'small'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'blockquoteCitation',
            view: {
                name: 'small'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'blockquoteCitation',
            view: ( modelElement, viewWriter ) => {
                const small = viewWriter.createEditableElement( 'small' );

                return toWidgetEditable( small, viewWriter );
            }
        } );
    }
}
