import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { enablePlaceholder } from '@ckeditor/ckeditor5-engine/src/view/placeholder';
import { toWidget, toWidgetEditable } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';
import RetainedData from './retaineddata';
import InsertRadioQuestionCommand from './insertradioquestioncommand';
import InsertRadioCommand from './insertradiocommand';
import { ALLOWED_ATTRIBUTES, filterAllowedAttributes } from './customelementattributepreservation.js';

export default class RadioQuestionEditing extends Plugin {
    static get requires() {
        return [ Widget, RetainedData ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();

        this.editor.commands.add( 'insertRadioQuestion', new InsertRadioQuestionCommand( this.editor ) );
        this.editor.commands.add( 'insertRadio', new InsertRadioCommand( this.editor ) );

        // Add a shortcut to the retained data ID function.
        this._nextRetainedDataId = this.editor.plugins.get('RetainedData').getNextId;

        // Because 'enter' events are consumed by Widget._onKeydown when the current selection is a non-inline
        // block widget, we have to re-fire them explicitly for radioDivs.
        // https://github.com/ckeditor/ckeditor5-widget/blob/bdeec63534d11a4fa682bb34990c698435bc13e3/src/widget.js#L174
        // https://github.com/ckeditor/ckeditor5-widget/blob/bdeec63534d11a4fa682bb34990c698435bc13e3/src/widget.js#L408
        this.listenTo( this.editor.editing.view.document, 'keydown', ( evt, data ) => {
            const selection = this.editor.model.document.selection;
            const selectedElement = selection.getSelectedElement();

            if ( selectedElement && selectedElement.name == 'radioDiv' ) {
                if ( data.domEvent.key === 'Enter' ) {
                    // This will end up calling our enter listener below.
                    this.editor.editing.view.document.fire( 'enter', { evt, data } );
                    data.preventDefault();
                    evt.stop();
                }
            }
        // Use 'highest' priority, because Widget._onKeydown listens at 'high'.
        // https://github.com/ckeditor/ckeditor5-widget/blob/bdeec63534d11a4fa682bb34990c698435bc13e3/src/widget.js#L92
        }, { priority: 'highest' } );

        // Override the default 'enter' key behavior to allow inserting new checklist options.
        this.listenTo( this.editor.editing.view.document, 'enter', ( evt, data ) => {
            const selection = this.editor.model.document.selection;
            const positionParent = selection.getLastPosition().parent;
            const selectedElement = selection.getSelectedElement();

            if ( positionParent.name == 'radioLabel' || ( selectedElement && selectedElement.name == 'radioDiv' ) ) {
                this.editor.execute( 'insertRadio' )
                data.preventDefault();
                evt.stop();
            }
        } );
    }

    _defineSchema() {
        const schema = this.editor.model.schema;

        schema.register( 'radioQuestion', {
            isObject: true,
            allowIn: 'section',
            allowAttributes: [ 'data-radio-group' ]
        } );

        schema.register( 'radioDiv', {
            isObject: true,
            allowIn: [ 'questionFieldset' ]
        } );

        schema.register( 'radioInput', {
            isInline: true,
            isObject: true,
            allowIn: [ 'radioDiv', 'tableCell' ],
            allowAttributes: [ 'id', 'name', 'value', 'data-correctness' ].concat(ALLOWED_ATTRIBUTES),
        } );

        schema.register( 'radioLabel', {
            isObject: true,
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
                return modelWriter.createElement( 'radioQuestion', {
                    'data-radio-group': viewElement.getAttribute( 'data-radio-group' )
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'radioQuestion',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createEditableElement( 'div', {
                    class: 'module-block module-block-radio',
                    'data-radio-group': modelElement.getAttribute( 'data-radio-group' )
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'radioQuestion',
            view: ( modelElement, viewWriter ) => {
                const radioQuestion = viewWriter.createContainerElement( 'div', {
                    class: 'module-block module-block-radio',
                    'data-radio-group': modelElement.getAttribute( 'data-radio-group' )
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

                return toWidget( div, viewWriter, { label: 'radio option widget' } );
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
                const id = viewElement.getAttribute('data-bz-retained') || this._nextRetainedDataId();

                // All radio buttons in the same question must share the same 'name' attribute,
                // so let's get a reference to the ancestor module block and use its group name
                // attribute, if available.
                let radioGroupName;
                try {
                    const moduleBlockRadioDiv = viewElement.parent.parent.parent.parent.parent;
                    // Try to use the existing name first; fall back to question group attribute.
                    radioGroupName = viewElement.getAttribute('name') || moduleBlockRadioDiv.getAttribute('data-radio-group');
                }
                catch (e) {
                    if (e instanceof TypeError) {
                        // We're not in a radio question; use something else for the group name.
                        radioGroupName = viewElement.getAttribute('name');
                    } else {
                        throw e;
                    }
                }

                return modelWriter.createElement( 'radioInput', new Map( [
                    ...filterAllowedAttributes(viewElement.getAttributes()),
                    [ 'id', id ],
                    [ 'name', radioGroupName ],
                    [ 'value', viewElement.getAttribute('value') ],
                    [ 'data-bz-retained', id ],
                    [ 'data-correctness', viewElement.getAttribute('data-correctness') || '' ]
                ] ) );
            }

        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'radioInput',
            view: ( modelElement, viewWriter ) => {
                const id = modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId();

                // All radio buttons in the same question must share the same 'name' attribute,
                // so let's get a reference to the ancestor module block and use its group name
                // attribute, if available.
                let radioGroupName;
                try {
                    const moduleBlockRadioDiv = modelElement.parent.parent.parent.parent.parent;
                    // Try to use the existing name first; fall back to question group attribute.
                    radioGroupName = modelElement.getAttribute('name') || moduleBlockRadioDiv.getAttribute('data-radio-group');
                }
                catch (e) {
                    if (e instanceof TypeError) {
                        // We're not in a radio question; use something else for the group name.
                        radioGroupName = modelElement.getAttribute('name');
                    } else {
                        throw e;
                    }
                }

                return viewWriter.createEmptyElement( 'input', new Map( [
                    ...filterAllowedAttributes(modelElement.getAttributes()),
                    [ 'type', 'radio' ],
                    [ 'id', id ],
                    [ 'name', radioGroupName ],
                    [ 'value', modelElement.getAttribute('value') ],
                    [ 'data-bz-retained', id ],
                    [ 'data-correctness', modelElement.getAttribute('data-correctness') || '' ]
                ] ) );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'radioInput',
            view: ( modelElement, viewWriter ) => {
                const id = modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId();

                // All radio buttons in the same question must share the same 'name' attribute,
                // so let's get a reference to the ancestor module block and use its group name
                // attribute, if available.
                let radioGroupName;
                try {
                    const moduleBlockRadioDiv = modelElement.parent.parent.parent.parent.parent;
                    // Try to use the existing name first; fall back to question group attribute.
                    radioGroupName = modelElement.getAttribute('name') || moduleBlockRadioDiv.getAttribute('data-radio-group');
                }
                catch (e) {
                    if (e instanceof TypeError) {
                        // We're not in a radio question; use something else for the group name.
                        radioGroupName = modelElement.getAttribute('name');
                    } else {
                        throw e;
                    }
                }

                return viewWriter.createEmptyElement( 'input', new Map( [
                    ...filterAllowedAttributes(modelElement.getAttributes()),
                    [ 'type', 'radio' ],
                    [ 'id', id ],
                    [ 'name', radioGroupName ],
                    [ 'value', modelElement.getAttribute('value') ],
                    [ 'data-bz-retained', id ],
                    [ 'data-correctness', modelElement.getAttribute('data-correctness') || '' ]
                ] ) );
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
                return viewWriter.createEditableElement( 'label', {
                    // HACK: Get the id of the radio this label corresponds to.
                    'for': modelElement.parent.getChild(0).getAttribute('id')
                } );
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
                return modelWriter.createElement( 'radioInlineFeedback' );
            }

        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'radioInlineFeedback',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createEditableElement( 'p', {
                    'class': 'feedback inline',
                } );
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
