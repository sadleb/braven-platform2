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
            allowIn: 'section'
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
                return modelWriter.createElement( 'textAreaQuestion' );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'textAreaQuestion',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createEditableElement( 'div', {
                    'class': 'module-block module-block-textarea',
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'textAreaQuestion',
            view: ( modelElement, viewWriter ) => {
                const textAreaQuestion = viewWriter.createContainerElement( 'div', {
                    'class': 'module-block module-block-textarea',
                } );

                return toWidget( textAreaQuestion, viewWriter, { label: 'textArea-question widget' } );
            }
        } );
    }
}
