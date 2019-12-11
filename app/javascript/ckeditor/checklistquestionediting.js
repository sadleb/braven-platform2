import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { toWidget, toWidgetEditable } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';
import InsertChecklistQuestionCommand from './insertchecklistquestioncommand';
import InsertCheckboxCommand from './insertcheckboxcommand';
import { preventCKEditorHandling } from './utils';

export default class ChecklistQuestionEditing extends Plugin {
    static get requires() {
        return [ Widget ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();

        this.editor.commands.add( 'insertChecklistQuestion', new InsertChecklistQuestionCommand( this.editor ) );
        this.editor.commands.add( 'insertCheckbox', new InsertCheckboxCommand( this.editor ) );

        // Override the default 'enter' key behavior for checkbox labels.
        this.listenTo( this.editor.editing.view.document, 'enter', ( evt, data ) => {
            const positionParent = this.editor.model.document.selection.getLastPosition().parent;
            if ( positionParent.name == 'checkboxLabel' ) {
                // Only insert a new checkbox if the current label is empty, but stop the event from
                // propogating regardless.
                if (!positionParent.isEmpty) {
                    this.editor.execute( 'insertCheckbox' )
                }
                data.preventDefault();
                evt.stop();
            }
        });

    }

    _defineSchema() {
        const schema = this.editor.model.schema;

        schema.register( 'checklistQuestion', {
            isObject: true,
            allowIn: 'section',
            allowAttributes: [ 'id' ]
        } );

        schema.register( 'question', {
            isObject: true,
            allowIn: 'checklistQuestion',
        } );

        schema.register( 'questionTitle', {
            isLimit: true,
            allowIn: 'question',
            allowContentOf: '$block'
        } );

        schema.register( 'questionForm', {
            // Cannot be split or left by the caret.
            isLimit: true,
            allowIn: 'question',
        } );

        schema.register( 'questionFieldset', {
            // Cannot be split or left by the caret.
            isLimit: true,
            allowIn: 'questionForm',
        } );

        schema.register( 'questionLegend', {
            // Cannot be split or left by the caret.
            isLimit: true,
            allowIn: 'questionFieldset',
            allowContentOf: '$block'
        } );

        schema.register( 'checkboxDiv', {
            allowIn: 'questionFieldset',
        } );

        schema.register( 'checkboxInput', {
            isInline: true,
            allowIn: 'checkboxDiv',
            allowAttributes: [ 'id', 'name', 'value' ]
        } );

        schema.register( 'checkboxLabel', {
            isInline: true,
            allowIn: 'checkboxDiv',
            allowContentOf: '$block',
            allowAttributes: [ 'for' ]
        } );

        schema.register( 'answer', {
            isObject: true,
            allowIn: 'checklistQuestion'
        } );

        schema.register( 'answerTitle', {
            isLimit: true,
            allowIn: 'answer',
            allowContentOf: '$block'
        } );

        schema.register( 'answerText', {
            isLimit: true,
            allowIn: 'answer',
            allowContentOf: '$root'
        } );

        schema.addChildCheck( ( context, childDefinition ) => {
            // Disallow adding questions inside answerText boxes.
            if ( context.endsWith( 'answerText' ) && childDefinition.name == 'checklistQuestion' ) {
                return false;
            }
        } );
    }

    _defineConverters() {
        const editor = this.editor;
        const conversion = editor.conversion;
        const { editing, data, model } = editor;

        // <checklistQuestion> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'div',
                classes: ['module-block', 'module-block-checkbox']
            },
            model: ( viewElement, modelWriter ) => {
                // Read the "data-id" attribute from the view and set it as the "id" in the model.
                return modelWriter.createElement( 'checklistQuestion', {
                    id: parseInt( viewElement.getAttribute( 'data-id' ) )
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'checklistQuestion',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createEditableElement( 'div', {
                    class: 'module-block module-block-checkbox',
                    'data-id': modelElement.getAttribute( 'id' )
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'checklistQuestion',
            view: ( modelElement, viewWriter ) => {
                const id = modelElement.getAttribute( 'id' );

                const checklistQuestion = viewWriter.createContainerElement( 'div', {
                    class: 'module-block module-block-checkbox',
                    'data-id': id
                } );

                return toWidget( checklistQuestion, viewWriter, { label: 'checklist-question widget' } );
            }
        } );

        // <question> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'question',
            view: {
                name: 'div',
                classes: 'question'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'question',
            view: {
                name: 'div',
                classes: 'question'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'question',
            view: ( modelElement, viewWriter ) => {
                const section = viewWriter.createContainerElement( 'div', { class: 'question' } );

                return toWidget( section, viewWriter );
            }
        } );

        // <questionTitle> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'questionTitle',
            view: {
                name: 'h5'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'questionTitle',
            view: {
                name: 'h5'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'questionTitle',
            view: ( modelElement, viewWriter ) => {
                const h5 = viewWriter.createEditableElement( 'h5', {
                } );

                return toWidgetEditable( h5, viewWriter );
            }
        } );

        // <questionForm> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'questionForm',
            view: {
                name: 'form'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'questionForm',
            view: {
                name: 'form'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'questionForm',
            view: ( modelElement, viewWriter ) => {
                const form = viewWriter.createContainerElement( 'form' );

                return toWidget( form, viewWriter );
            }
        } );

        // <questionFieldset> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'questionFieldset',
            view: {
                name: 'fieldset'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'questionFieldset',
            view: {
                name: 'fieldset'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'questionFieldset',
            view: ( modelElement, viewWriter ) => {
                const fieldset = viewWriter.createContainerElement( 'fieldset' );

                return toWidget( fieldset, viewWriter );
            }
        } );

        // <checkboxDiv> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'checkboxDiv',
            view: {
                name: 'div'
            }

        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'checkboxDiv',
            view: {
                name: 'div'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'checkboxDiv',
            view: ( modelElement, viewWriter ) => {
                const div = viewWriter.createContainerElement( 'div', {} );

                const widgetContents = viewWriter.createUIElement(
                    'select',
                    {
                        'name': 'test',
                        'onchange': 'console.log("TODO: SAVE CORRECTNESS")'
                    },
                    function( domDocument ) {
                        const domElement = this.toDomElement( domDocument );

                        // Set up the select values.
                        domElement.innerHTML = `
                            <option value="correct">Correct</option>
                            <option value="incorrect">Incorrect</option>
                            <option value="maybe">Maybe</option>`;

                        // Default to the stored value.
                        domElement.value = modelElement.getAttribute( 'data-correctness' );

                        // Allow toggling this input in the editor UI.
                        preventCKEditorHandling(domElement, editor);

                        return domElement;
                    } );

                const insertPosition = viewWriter.createPositionAt( div, 0 );
                viewWriter.insert( insertPosition, widgetContents );

                return toWidget( div, viewWriter );
            }
        } );

        // <checkboxInput> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'checkboxInput',
            view: {
                name: 'input',
                type: 'checkbox'
            }

        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'checkboxInput',
            view: ( modelElement, viewWriter ) => {
                const input = viewWriter.createEmptyElement( 'input', {'type': 'checkbox'} );
                return input;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'checkboxInput',
            view: ( modelElement, viewWriter ) => {
                const input = viewWriter.createEmptyElement( 'input', {'type': 'checkbox'} );
                return toWidget( input, viewWriter );
            }
        } );

        // <checkboxLabel> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'checkboxLabel',
            view: {
                name: 'label'
            }

        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'checkboxLabel',
            view: {
                name: 'label'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'checkboxLabel',
            view: ( modelElement, viewWriter ) => {
                const label = viewWriter.createEditableElement( 'label', {} );

                return toWidgetEditable( label, viewWriter );
            }
        } );

        // <answer> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'answer',
            view: {
                name: 'div',
                classes: 'answer'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'answer',
            view: {
                name: 'div',
                classes: 'answer'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'answer',
            view: ( modelElement, viewWriter ) => {
                const section = viewWriter.createContainerElement( 'div', { class: 'answer' } );

                return toWidget( section, viewWriter );
            }
        } );

        // <answerTitle> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'answerTitle',
            view: {
                name: 'h5'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'answerTitle',
            view: {
                name: 'h5'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'answerTitle',
            view: ( modelElement, viewWriter ) => {
                const h5 = viewWriter.createEditableElement( 'h5', {} );

                return toWidgetEditable( h5, viewWriter );
            }
        } );

        // <answerText> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'answerText',
            view: {
                name: 'div'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'answerText',
            view: {
                name: 'div'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'answerText',
            view: ( modelElement, viewWriter ) => {
                const div = viewWriter.createEditableElement( 'div', {} );

                return toWidgetEditable( div, viewWriter );
            }
        } );

    }
}
