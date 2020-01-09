import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { toWidget } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';
import InsertTextAreaQuestionCommand from './inserttextareaquestioncommand';
import InsertTextAreaCommand from './inserttextareacommand';

export default class TextAreaQuestionEditing extends Plugin {
    static get requires() {
        return [ Widget ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();

        this.editor.commands.add( 'insertTextAreaQuestion', new InsertTextAreaQuestionCommand( this.editor ) );
        this.editor.commands.add( 'insertTextArea', new InsertTextAreaCommand( this.editor ) );
    }

    _defineSchema() {
        const schema = this.editor.model.schema;

        schema.register( 'textAreaQuestion', {
            isObject: true,
            allowIn: 'section',
            allowAttributes: [ 'data-bz-retained' ]
        } );

        schema.extend( 'question', {
            allowIn: 'textAreaQuestion'
        } );

        schema.addChildCheck( ( context, childDefinition ) => {
            // Disallow adding questions inside answerText boxes.
            if ( context.endsWith( 'answerText' ) && childDefinition.name == 'textAreaQuestion' ) {
                return false;
            }
        } );
    }

    _defineConverters() {
        const editor = this.editor;
        const conversion = editor.conversion;
        const { editing, data, model } = editor;

        // <textAreaQuestion> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'div',
                classes: ['module-block', 'module-block-textarea']
            },
            model: ( viewElement, modelWriter ) => {
                // Read the "data-bz-retained" attribute from the view and set it as the "id" in the model.
                return modelWriter.createElement( 'textAreaQuestion', {
                    'data-bz-retained': viewElement.getAttribute( 'data-bz-retained' )
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'textAreaQuestion',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createEditableElement( 'div', {
                    class: 'module-block module-block-textarea',
                    'data-bz-retained': modelElement.getAttribute( 'data-bz-retained' )
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'textAreaQuestion',
            view: ( modelElement, viewWriter ) => {
                const id = modelElement.getAttribute( 'data-bz-retained' );

                const textAreaQuestion = viewWriter.createContainerElement( 'div', {
                    class: 'module-block module-block-textarea',
                    'data-bz-retained': id
                } );

                return toWidget( textAreaQuestion, viewWriter, { label: 'textArea-question widget' } );
            }
        } );
    }
}
