import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { enablePlaceholder } from '@ckeditor/ckeditor5-engine/src/view/placeholder';
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

        schema.register( 'checkboxDiv', {
            allowIn: 'questionFieldset',
        } );

        schema.register( 'checkboxInput', {
            isInline: true,
            allowIn: 'checkboxDiv',
            allowAttributes: [ 'id', 'name', 'value', 'data-bz-retained' ]
        } );

        schema.register( 'checkboxLabel', {
            isInline: true,
            allowIn: 'checkboxDiv',
            allowContentOf: '$block',
            allowAttributes: [ 'for' ]
        } );

        schema.register( 'checkboxInlineFeedback', {
            isLimit: true,
            allowIn: 'checkboxDiv',
            allowContentOf: '$block'
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
                    id: viewElement.getAttribute( 'data-id' )
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

        // <checkboxDiv> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'checkboxDiv',
            view: {
                name: 'div',
                classes: ['module-checkbox-div']
            }

        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'checkboxDiv',
            view: {
                name: 'div',
                classes: ['module-checkbox-div']
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'checkboxDiv',
            view: ( modelElement, viewWriter ) => {
                const div = viewWriter.createContainerElement( 'div', {
                    'class': 'module-checkbox-div'
                } );

                const widgetContents = viewWriter.createUIElement(
                    'select',
                    {
                        'name': 'test',
                        'onchange': 'addRetainedDataID(this)'
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
            view: {
                name: 'input',
                type: 'checkbox'
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'checkboxInput', {
                    'id': viewElement.getAttribute( 'id' ),
                    'data-bz-retained': viewElement.getAttribute('data-bz-retained') || addRetainedDataID(viewElement)
                } );
            }

        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'checkboxInput',
            view: ( modelElement, viewWriter ) => {
                const input = viewWriter.createEmptyElement( 'input', {
                    'type': 'checkbox',
                    'id': modelElement.getAttribute( 'id' ),
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained') || addRetainedDataID(modelElement)
                } );
                return input;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'checkboxInput',
            view: ( modelElement, viewWriter ) => {
                const input = viewWriter.createEmptyElement( 'input', {
                    'type': 'checkbox',
                    'id': modelElement.getAttribute( 'id' ),
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained') || addRetainedDataID(modelElement)
                } );
                return toWidget( input, viewWriter );
            }
        } );

        // <checkboxLabel> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'label'
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'checkboxLabel', {
                    // HACK: Get the id of the checkbox this label corresponds to.
                    'for': viewElement.parent.getChild(0).getAttribute('id')
                } );
            }

        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'checkboxLabel',
            view: ( modelElement, viewWriter ) => {
                const label = viewWriter.createEditableElement( 'label', {
                    // HACK: Get the id of the checkbox this label corresponds to.
                    'for': modelElement.parent.getChild(0).getAttribute('id')
                } );

                return label;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'checkboxLabel',
            view: ( modelElement, viewWriter ) => {
                const label = viewWriter.createEditableElement( 'label', {
                    // NOTE: We don't set the 'for' attribute in the editing view, so that clicking in the label
                    // editable to type doesn't also toggle the checkbox.
                } );

                enablePlaceholder( {
                    view: editing.view,
                    element: label,
                    text: 'Answer text'
                } );

                return toWidgetEditable( label, viewWriter );
            }
        } );

        // <checkboxInlineFeedback> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'p',
                classes: ['inline', 'feedback']
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'checkboxInlineFeedback', {
                } );
            }

        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'checkboxInlineFeedback',
            view: ( modelElement, viewWriter ) => {
                const p = viewWriter.createEditableElement( 'p', {
                    'class': 'feedback inline',
                } );

                return p;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'checkboxInlineFeedback',
            view: ( modelElement, viewWriter ) => {
                const p = viewWriter.createEditableElement( 'p', {
                    'class': 'feedback inline',
                } );

                enablePlaceholder( {
                    view: editing.view,
                    element: p,
                    text: 'Inline feedback (optional)'
                } );

                return toWidgetEditable( p, viewWriter );
            }
        } );
    }
}
