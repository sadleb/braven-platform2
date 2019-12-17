import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { toWidget, toWidgetEditable } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';
import InsertRadioQuestionCommand from './insertradioquestioncommand';
import InsertRadioCommand from './insertradiocommand';
import { preventCKEditorHandling } from './utils';

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
            allowIn: 'questionFieldset',
        } );

        schema.register( 'radioInput', {
            isInline: true,
            allowIn: 'radioDiv',
            allowAttributes: [ 'id', 'name', 'value' ]
        } );

        schema.register( 'radioLabel', {
            isInline: true,
            allowIn: 'radioDiv',
            allowContentOf: '$block',
            allowAttributes: [ 'for' ]
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
                    id: parseInt( viewElement.getAttribute( 'data-id' ) )
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
                name: 'div'
            }

        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'radioDiv',
            view: {
                name: 'div'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'radioDiv',
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

        // <radioInput> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'input',
                type: 'radio'
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'radioInput', {
                    'id': viewElement.getAttribute( 'id' )
                } );
            }

        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'radioInput',
            view: ( modelElement, viewWriter ) => {
                const input = viewWriter.createEmptyElement( 'input', {
                    'type': 'radio',
                    'id': modelElement.getAttribute( 'id' )
                } );
                return input;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'radioInput',
            view: ( modelElement, viewWriter ) => {
                const input = viewWriter.createEmptyElement( 'input', {
                    'type': 'radio',
                    'id': modelElement.getAttribute( 'id' )
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

                return toWidgetEditable( label, viewWriter );
            }
        } );
    }
}
