import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { enablePlaceholder } from '@ckeditor/ckeditor5-engine/src/view/placeholder';
import { toWidget, toWidgetEditable } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';
import InsertRadioQuestionCommand from './insertradioquestioncommand';
import InsertRadioCommand from './insertradiocommand';

export default class RadioQuestionEditing extends Plugin {
    static get requires() {
        return [ Widget ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();

        this.editor.commands.add( 'insertRadioQuestion', new InsertRadioQuestionCommand( this.editor ) );
        this.editor.commands.add( 'insertRadio', new InsertRadioCommand( this.editor ) );

        // Override the default 'enter' key behavior for radio labels.
        this.listenTo( this.editor.editing.view.document, 'enter', ( evt, data ) => {
            const positionParent = this.editor.model.document.selection.getLastPosition().parent;
            if ( positionParent.name == 'radioLabel' ) {
                // Only insert a new radio if the current label is empty, but stop the event from
                // propogating regardless.
                if (!positionParent.isEmpty) {
                    this.editor.execute( 'insertRadio' )
                }
                data.preventDefault();
                evt.stop();
            }
        });
    }

    _defineSchema() {
        const schema = this.editor.model.schema;

        schema.register( 'radioQuestion', {
            isObject: true,
            allowIn: 'section',
            allowAttributes: [ 'id' ]
        } );

        schema.register( 'radioDiv', {
            allowIn: [ 'questionFieldset' ]
        } );

        schema.register( 'radioInput', {
            isInline: true,
            isObject: true,
            allowIn: [ 'radioDiv', 'tableCell' ],
            allowAttributes: [ 'id', 'name', 'value', 'data-correctness' ]
        } );

        schema.register( 'radioLabel', {
            isInline: true,
            allowIn: 'radioDiv',
            allowContentOf: '$block',
            allowAttributes: [ 'for' ]
        } );

        schema.register( 'radioInlineFeedback', {
            isLimit: true,
            allowIn: 'radioDiv',
            allowContentOf: '$block'
        } );

        schema.addChildCheck( ( context, childDefinition ) => {
            // Disallow adding questions inside answerText boxes.
            if ( context.endsWith( 'answerText' ) && childDefinition.name == 'radioQuestion' ) {
                return false;
            }
        } );
    }

    _defineConverters() {
        const editor = this.editor;
        const conversion = editor.conversion;
        const { editing, data, model } = editor;

        // <radioQuestion> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'div',
                classes: ['module-block', 'module-block-radio']
            },
            model: ( viewElement, modelWriter ) => {
                // Read the "data-id" attribute from the view and set it as the "id" in the model.
                return modelWriter.createElement( 'radioQuestion', {
                    id: viewElement.getAttribute( 'data-id' )
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'radioQuestion',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createEditableElement( 'div', {
                    class: 'module-block module-block-radio',
                    'data-id': modelElement.getAttribute( 'id' )
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'radioQuestion',
            view: ( modelElement, viewWriter ) => {
                const id = modelElement.getAttribute( 'id' );

                const radioQuestion = viewWriter.createContainerElement( 'div', {
                    class: 'module-block module-block-radio',
                    'data-id': id
                } );

                return toWidget( radioQuestion, viewWriter, { label: 'radio-question widget' } );
            }
        } );

        // <radioDiv> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'radioDiv',
            view: {
                name: 'div',
                classes: ['module-radio-div']
            }

        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'radioDiv',
            view: {
                name: 'div',
                classes: ['module-radio-div']
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'radioDiv',
            view: ( modelElement, viewWriter ) => {
                const div = viewWriter.createContainerElement( 'div', {
                    'class': 'module-radio-div'
                } );

                return toWidget( div, viewWriter );
            }
        } );

        // <radioInput> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'input',
                attributes: {
                    type: 'radio'
                }
            },
            model: ( viewElement, modelWriter ) => {
                // All radio buttons in the same question must share the same 'name' attribute,
                // so let's get a reference to the ancestor module block and use its ID.
                let radioGroupName;
                try {
                    const moduleBlockRadioDiv = viewElement.parent.parent.parent.parent.parent;
                    // Try to use the existing name first; fall back to question ID.
                    radioGroupName = viewElement.getAttribute('name') || moduleBlockRadioDiv.getAttribute('id');
                }
                catch (e) {
                    if (e instanceof TypeError) {
                        // We're not in a radio question; use something else for the group name.
                        radioGroupName = viewElement.getAttribute('name');
                    } else {
                        throw e;
                    }
                }

                return modelWriter.createElement( 'radioInput', {
                    'id': viewElement.getAttribute( 'id' ),
                    'name': radioGroupName,
                    'data-bz-retained': viewElement.getAttribute('data-bz-retained') || addRetainedDataID(viewElement),
                    'data-correctness': viewElement.getAttribute('data-correctness') || ''
                } );
            }

        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'radioInput',
            view: ( modelElement, viewWriter ) => {
                // All radio buttons in the same question must share the same 'name' attribute,
                // so let's get a reference to the ancestor module block and use its ID.
                let radioGroupName;
                try {
                    const moduleBlockRadioDiv = modelElement.parent.parent.parent.parent.parent;
                    // Try to use the existing name first; fall back to question ID.
                    radioGroupName = modelElement.getAttribute('name') || moduleBlockRadioDiv.getAttribute('id');
                }
                catch (e) {
                    if (e instanceof TypeError) {
                        // We're not in a radio question; use something else for the group name.
                        radioGroupName = modelElement.getAttribute('name');
                    } else {
                        throw e;
                    }
                }

                const input = viewWriter.createEmptyElement( 'input', {
                    'type': 'radio',
                    'id': modelElement.getAttribute( 'id' ),
                    'name': radioGroupName,
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained') || addRetainedDataID(modelElement),
                    'data-correctness': modelElement.getAttribute('data-correctness') || ''
                } );
                return input;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'radioInput',
            view: ( modelElement, viewWriter ) => {
                // All radio buttons in the same question must share the same 'name' attribute,
                // so let's get a reference to the ancestor module block and use its ID.
                let radioGroupName;
                try {
                    const moduleBlockRadioDiv = modelElement.parent.parent.parent.parent.parent;
                    // Try to use the existing name first; fall back to question ID.
                    radioGroupName = modelElement.getAttribute('name') || moduleBlockRadioDiv.getAttribute('id');
                }
                catch (e) {
                    if (e instanceof TypeError) {
                        // We're not in a radio question; use something else for the group name.
                        radioGroupName = modelElement.getAttribute('name');
                    } else {
                        throw e;
                    }
                }

                const input = viewWriter.createEmptyElement( 'input', {
                    'type': 'radio',
                    'id': modelElement.getAttribute( 'id' ),
                    'name': radioGroupName,
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained') || addRetainedDataID(modelElement),
                    'data-correctness': modelElement.getAttribute('data-correctness') || ''
                } );
                return toWidget( input, viewWriter );
            }
        } );

        // <radioLabel> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'label'
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'radioLabel', {
                    // HACK: Get the id of the radio this label corresponds to.
                    'for': viewElement.parent.getChild(0).getAttribute('id')
                } );
            }

        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'radioLabel',
            view: ( modelElement, viewWriter ) => {
                const label = viewWriter.createEditableElement( 'label', {
                    // HACK: Get the id of the radio this label corresponds to.
                    'for': modelElement.parent.getChild(0).getAttribute('id')
                } );

                return label;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'radioLabel',
            view: ( modelElement, viewWriter ) => {
                const label = viewWriter.createEditableElement( 'label', {
                    // NOTE: We don't set the 'for' attribute in the editing view, so that clicking in the label
                    // editable to type doesn't also toggle the radio.
                } );

                enablePlaceholder( {
                    view: editing.view,
                    element: label,
                    text: 'Answer text'
                } );

                return toWidgetEditable( label, viewWriter );
            }
        } );

        // <radioInlineFeedback> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'p',
                classes: ['inline', 'feedback']
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'radioInlineFeedback', {
                } );
            }

        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'radioInlineFeedback',
            view: ( modelElement, viewWriter ) => {
                const p = viewWriter.createEditableElement( 'p', {
                    'class': 'feedback inline',
                } );

                return p;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'radioInlineFeedback',
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
