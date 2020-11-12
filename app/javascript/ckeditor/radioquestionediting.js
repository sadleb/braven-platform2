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
     * <questionFieldset>
     *   <radioDiv>
     *     <radioInput/>
     *     <radioLabel>$text</radioLabel>
     *   </radioDiv>
     * </questionFieldset>
     */
    _defineSchema() {
        const schema = this.editor.model.schema;

        schema.register( 'radioDiv', {
            isLimit: true,
            isSelectable: true,
            allowIn: [ 'questionFieldset' ]
        } );

        schema.register( 'radioInput', {
            isInline: true,
            allowIn: [ 'radioDiv' ],
            allowAttributes: [ 'id', 'name', 'value', 'data-bz-retained' ],
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
                const radioGroupName = viewElement.getAttribute('name');
                const radioValue = viewElement.getAttribute('value');
                return writer.createElement( 'radioInput', new Map( [
                    [ 'id', [ radioGroupName, radioValue ].join( '_' ) ],
                    [ 'value', radioValue ],
                    [ 'name', radioGroupName ],
                    [ 'data-bz-retained', radioGroupName ],
                ] ) );
            }

        } );
        conversion.for( 'downcast' ).elementToElement( {
            model: 'radioInput',
            view: ( modelElement, { writer } ) => {
                const radioGroupName = modelElement.getAttribute('name');
                const radioValue = modelElement.getAttribute('value');
                return writer.createEmptyElement( 'input', new Map( [
                    [ 'type', 'radio' ],
                    [ 'id', [ radioGroupName, radioValue ].join( '_' ) ],
                    [ 'value', radioValue ],
                    [ 'name', radioGroupName ],
                    [ 'data-bz-retained', radioGroupName ],
                ] ) );
            }
        } );

        // <radioLabel> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'label'
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
                return writer.createEditableElement( 'label', {
                    // HACK: Get the id of the radio this label corresponds to.
                    'for': modelElement.parent.getChild(0).getAttribute('id')
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'radioLabel',
            view: ( modelElement, { writer } ) => {
                const label = writer.createEditableElement( 'label', {
                    // NOTE: We don't set the 'for' attribute in the editing view, so that clicking in the label
                    // editable to type doesn't also toggle the radio.
                } );

                enablePlaceholder( {
                    view: editing.view,
                    element: label,
                    text: 'Answer text'
                } );

                return toWidgetEditable( label, writer );
            }
        } );
    }
}
