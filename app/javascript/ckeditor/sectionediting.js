import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { toWidget, toWidgetEditable } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';
import InsertSectionCommand from './insertsectioncommand';

export default class SectionEditing extends Plugin {
    static get requires() {
        return [ Widget ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();

        this.editor.commands.add( 'insertSection', new InsertSectionCommand( this.editor ) );
    }

    _defineSchema() {
        const schema = this.editor.model.schema;

        schema.register( 'section', {
            //isObject: true,

            allowIn: '$root',

            // Allow content which is allowed in the root (e.g. paragraphs).
            allowContentOf: '$root',

            allowAttributes: [ 'id' ]
        } );

        schema.addChildCheck( ( context, childDefinition ) => {
            // Disallow sections within sections, at *any* level of nesting.
            if ( [...context.getNames()].includes( 'section' ) && childDefinition.name == 'section' ) {
                return false;
            }
        } );
    }

    _defineConverters() {
        const editor = this.editor;
        const conversion = editor.conversion;

        // <section> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'section',
                classes: ['content-section']
            },
            model: ( viewElement, modelWriter ) => {
                // Read the "data-id" attribute from the view and set it as the "id" in the model.
                return modelWriter.createElement( 'section', {
                    id: parseInt( viewElement.getAttribute( 'data-id' ) )
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'section',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createEditableElement( 'section', {
                    class: 'content-section',
                    'data-id': modelElement.getAttribute( 'id' )
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'section',
            view: ( modelElement, viewWriter ) => {
                const id = modelElement.getAttribute( 'id' );

                const section = viewWriter.createContainerElement( 'section', {
                    class: 'content-section',
                    'data-id': id
                } );

                // Note: sections are not converted into widgets! They're just an element.
                return section;
            }
        } );
    }
}
