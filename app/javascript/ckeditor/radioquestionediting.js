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

    /**
     * Example valid structure:
     *
     * <fieldset>
     *   <radioDiv>
     *     <radioInput/>
     *     <radioLabel>$text</radioLabel>
     *   </radioDiv>
     * </fieldset>
     */
    _defineSchema() {
        const schema = this.editor.model.schema;

        schema.register( 'radioDiv', {
            isLimit: true,
            isSelectable: true,
            allowIn: [ 'fieldset' ]
        } );

        schema.register( 'radioInput', {
            isInline: true,
            allowIn: [ 'radioDiv' ],
            allowAttributes: [ 'id', 'name', 'value' ],
        } );

        schema.register( 'radioLabel', {
            isLimit: true,
            isInline: true,
            allowIn: 'radioDiv',
            allowContentOf: '$block',
            allowAttributes: [ 'for' ]
        } );
    }

    _defineConverters() {
        const editor = this.editor;
        const conversion = editor.conversion;
        const { editing, data, model } = editor;

        // <radioDiv> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'radioDiv',
            view: {
                name: 'div',
                classes: ['custom-content-radio-div'],
            },
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'radioDiv',
            view: {
                name: 'div',
                classes: ['custom-content-radio-div'],
            },
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'radioDiv',
            view: ( modelElement, { writer } ) => {
                const div = writer.createContainerElement( 'div', {
                    'class': 'custom-content-radio-div',
                } );
                return toWidget( div, writer, { label: 'radio option widget' } );
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
            model: ( viewElement, { writer } ) => {
                return writer.createElement( 'radioInput', {
                    'id': viewElement.getAttribute('id'),
                    'value': viewElement.getAttribute('value'),
                    'name': viewElement.getAttribute('name'),
                } );
            }

        } );
        conversion.for( 'downcast' ).elementToElement( {
            model: 'radioInput',
            view: ( modelElement, { writer } ) => {
                return writer.createEmptyElement( 'input', {
                    'type': 'radio',
                    'id': modelElement.getAttribute('id'),
                    'value': modelElement.getAttribute('value'),
                    'name': modelElement.getAttribute('name'),
                } );
            }
        } );

        // <radioLabel> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'label',
                classes: ['radio-label'],
            },
            model: ( viewElement, { writer } ) => {
                return writer.createElement( 'radioLabel', {
                    // HACK: Get the id of the radio this label corresponds to.
                    'for': viewElement.parent.getChild(0).getAttribute('id')
                } );
            }

        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'radioLabel',
            view: ( modelElement, { writer } ) => {
                return writer.createContainerElement( 'label', {
                    // HACK: Get the id of the radio this label corresponds to.
                    'for': modelElement.parent.getChild(0).getAttribute('id'),
                    'class': 'radio-label',
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'radioLabel',
            view: ( modelElement, { writer } ) => {
                const label = writer.createEditableElement( 'label', {
                    // NOTE: We don't set the 'for' attribute in the editing view, so that clicking in the label
                    // editable to type doesn't also toggle the radio.
                    'class': 'radio-label',
                } );

                enablePlaceholder( {
                    view: editing.view,
                    element: label,
                    text: 'Answer text'
                } );

                return toWidgetEditable( label, writer, { 'label': 'radio label' } );
            }
        } );
    }
}
