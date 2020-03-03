import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { enablePlaceholder } from '@ckeditor/ckeditor5-engine/src/view/placeholder';
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
            allowIn: '$root',
            allowContentOf: '$root',
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
        const { editing, data, model } = editor;

        // <section> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'section',
                classes: ['content-section']
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'section' );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'section',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createContainerElement( 'section', {
                    'class': 'content-section',
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'section',
            view: ( modelElement, viewWriter ) => {
                const section = viewWriter.createContainerElement( 'section', {
                    'class': 'content-section',
                } );

                enablePlaceholder( {
                    view: editing.view,
                    element: section,
                    text: '[Empty section]',
                    isDirectHost: false
                } );

                return section;
            }
        } );
    }
}
