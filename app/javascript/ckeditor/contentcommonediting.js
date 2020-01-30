import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { enablePlaceholder } from '@ckeditor/ckeditor5-engine/src/view/placeholder';
import { toWidget, toWidgetEditable } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';
import RetainedData from './setattributescommand';
import InsertTextInputCommand from './inserttextinputcommand';
import InsertDoneButtonCommand from './insertdonebuttoncommand';

export default class ContentCommonEditing extends Plugin {
    static get requires() {
        return [ Widget, RetainedData ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();

        this.editor.commands.add( 'insertTextInput', new InsertTextInputCommand( this.editor ) );
        this.editor.commands.add( 'insertDoneButton', new InsertDoneButtonCommand( this.editor ) );

        // Add a shortcut to the retained data ID function.
        this._nextRetainedDataId = this.editor.plugins.get('RetainedData').getNextId;
    }

    _defineSchema() {
        const schema = this.editor.model.schema;

        // Shared elements.
        schema.register( 'content', {
            isObject: true,
            allowIn: [ 'blockquoteContent', 'tableContent', 'iframeContent', 'videoContent' ],
            allowContentOf: '$root'
        });

        schema.register( 'contentTitle', {
            isLimit: true,
            allowIn: 'content',
            allowContentOf: '$block'
        } );

        schema.register( 'contentBody', {
            isLimit: true,
            allowIn: 'content',
            allowContentOf: '$root'
        } );

        schema.register( 'question', {
            isObject: true,
            allowIn: [ 'checklistQuestion', 'radioQuestion', 'matchingQuestion' ],
            allowAttributes: [ 'data-instant-feedback' ]
        } );

        schema.extend( 'paragraph', {
            allowIn: 'question'
        } );

        schema.register( 'questionTitle', {
            isLimit: true,
            allowIn: 'question',
            allowContentOf: '$block'
        } );

        schema.register( 'questionBody', {
            isLimit: true,
            allowIn: 'question',
            allowContentOf: '$root'
        } );

        schema.register( 'questionForm', {
            // Cannot be split or left by the caret.
            isLimit: true,
            allowIn: [ 'question', 'content' ]
        } );

        schema.register( 'questionFieldset', {
            // Cannot be split or left by the caret.
            isLimit: true,
            allowIn: 'questionForm',
        } );

        schema.register( 'doneButton', {
            isObject: true,
            allowIn: [ 'section', 'questionForm', 'question' ],
            allowAttributes: [ 'data-bz-retained', 'type', 'value', 'data-time-updated' ],
        } );

        schema.register( 'legend', {
            // Cannot be split or left by the caret.
            isLimit: true,
            allowIn: 'questionFieldset',
            allowContentOf: '$block'
        } );

        schema.register( 'answer', {
            isObject: true,
            allowIn: [ 'checklistQuestion', 'radioQuestion' ]
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

        // Shared inputs.
        schema.register( 'textInput', {
            isObject: true,
            allowAttributes: [ 'data-bz-retained', 'type', 'placeholder' ],
            allowIn: [ '$root', '$block', 'tableCell' ],
        } );

        schema.register( 'textArea', {
            isObject: true,
            allowAttributes: [ 'data-bz-retained', 'placeholder' ],
            allowIn: [ '$root', '$block', 'checkboxDiv', 'radioDiv', 'tableCell', 'questionFieldset' ],
        } );

        schema.register( 'fileUpload', {
            isObject: true,
            allowAttributes: [ 'class', 'data-bz-retained', 'data-bz-share-release', 'type' ],
            allowIn: [ '$root' ],
        } );

        schema.register( 'slider', {
            isObject: true,
            allowAttributes: [ 'data-bz-retained', 'type', 'max', 'min', 'step' ],
            allowIn: [ '$root' ],
        } );

        schema.register( 'select', {
            isObject: true,
            allowAttributes: [ 'data-bz-retained', 'id', 'name' ],
            allowIn: [ '$root' ],
        } );

        schema.register( 'selectOption', {
            isObject: true,
            allowAttributes: [ 'value', 'selected' ],
            allowIn: [ 'select' ],
            allowContentOf: '$block'
        } );
    }

    _defineConverters() {
        const editor = this.editor;
        const conversion = editor.conversion;
        const { editing, data, model } = editor;

        // <content> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'content',
            view: {
                name: 'div',
                classes: 'content'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'content',
            view: {
                name: 'div',
                classes: 'content'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'content',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createContainerElement( 'div', { class: 'content' } );
            }
        } );

        // <contentTitle> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'contentTitle',
            view: {
                name: 'h5'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'contentTitle',
            view: {
                name: 'h5'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'contentTitle',
            view: ( modelElement, viewWriter ) => {
                const h5 = viewWriter.createEditableElement( 'h5', {
                } );

                enablePlaceholder( {
                    view: editing.view,
                    element: h5,
                    text: 'Content Title'
                } );

                return toWidgetEditable( h5, viewWriter );
            }
        } );

        // <contentBody> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'contentBody',
            view: {
                name: 'div',
                classes: ['content-body']
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'contentBody',
            view: {
                name: 'div',
                classes: ['content-body']
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'contentBody',
            view: ( modelElement, viewWriter ) => {
                const div = viewWriter.createEditableElement( 'div', {
                    'class': 'content-body'
                } );

                enablePlaceholder( {
                    view: editing.view,
                    element: div,
                    text: 'Content body',
                    isDirectHost: false
                } );

                return toWidgetEditable( div, viewWriter );
            }
        } );

        // <question> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'div',
                classes: 'question'
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'question', {
                    'data-instant-feedback': viewElement.getAttribute('data-instant-feedback') || false,
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'question',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createContainerElement( 'div', {
                    'class': 'question',
                    'data-instant-feedback': modelElement.getAttribute('data-instant-feedback') || false,
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'question',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createContainerElement( 'div', {
                    'class': 'question',
                    'data-instant-feedback': modelElement.getAttribute('data-instant-feedback') || false,
                } );
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

                enablePlaceholder( {
                    view: editing.view,
                    element: h5,
                    text: 'Question Title'
                } );

                return toWidgetEditable( h5, viewWriter );
            }
        } );

        // <questionBody> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'questionBody',
            view: {
                name: 'div'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'questionBody',
            view: {
                name: 'div'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'questionBody',
            view: ( modelElement, viewWriter ) => {
                const div = viewWriter.createEditableElement( 'div', {} );

                enablePlaceholder( {
                    view: editing.view,
                    element: div,
                    text: 'Question body',
                    isDirectHost: false
                } );

                return toWidgetEditable( div, viewWriter );
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
                return viewWriter.createContainerElement( 'form' );
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
                return viewWriter.createContainerElement( 'fieldset' );
            }
        } );

        // <doneButton> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'input',
                classes: 'done-button',
                attributes: {
                    'type': 'button',
                    'value': 'Done',
                }
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'doneButton', {
                    'data-bz-retained': viewElement.getAttribute('data-bz-retained') || this._nextRetainedDataId(),
                    'data-time-updated': viewElement.getAttribute('data-time-updated') || '',
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'doneButton',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createContainerElement( 'input', {
                    'type': 'button',
                    'value': 'Done',
                    'class': 'done-button',
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId(),
                    'data-time-updated': modelElement.getAttribute('data-time-updated') || '',
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'doneButton',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createContainerElement( 'input', {
                    'type': 'button',
                    'value': 'Done',
                    'class': 'done-button',
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId(),
                    'data-time-updated': modelElement.getAttribute('data-time-updated') || '',
                } );
            }
        } );

        // <questionLegend> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'legend',
            view: {
                name: 'legend'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'legend',
            view: {
                name: 'legend'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'legend',
            view: ( modelElement, viewWriter ) => {
                const legend = viewWriter.createEditableElement( 'legend' );

                enablePlaceholder( {
                    view: editing.view,
                    element: legend,
                    text: 'Legend'
                } );

                return toWidgetEditable( legend, viewWriter );
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
                return viewWriter.createContainerElement( 'div', { class: 'answer' } );
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
                const h5 = viewWriter.createContainerElement( 'h5', {} );

                enablePlaceholder( {
                    view: editing.view,
                    element: h5,
                    text: 'Answer Title'
                } );

                return h5;
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

                enablePlaceholder( {
                    view: editing.view,
                    element: div,
                    text: 'Answer body',
                    isDirectHost: false
                } );

                return toWidgetEditable( div, viewWriter );
            }
        } );

        // Misc elements

        // <textInput> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'input',
                attributes: {
                    'type': 'text'
                }
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'textInput', {
                    'data-bz-retained': viewElement.getAttribute('data-bz-retained') || this._nextRetainedDataId(),
                    'placeholder': viewElement.getAttribute('placeholder') || ''
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'textInput',
            view: ( modelElement, viewWriter ) => {
                const input = viewWriter.createEmptyElement( 'input', {
                    'type': 'text',
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId(),
                    'placeholder': modelElement.getAttribute('placeholder') || ''
                } );
                return input;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'textInput',
            view: ( modelElement, viewWriter ) => {
                const input = viewWriter.createEmptyElement( 'input', {
                    'type': 'text',
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId(),
                    'placeholder': modelElement.getAttribute('placeholder') || ''
                } );
                return toWidget( input, viewWriter );
            }
        } );

        // <textArea> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'textarea',
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'textArea', {
                    'data-bz-retained': viewElement.getAttribute('data-bz-retained') || this._nextRetainedDataId(),
                    'placeholder': viewElement.getAttribute('placeholder') || ''
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'textArea',
            view: ( modelElement, viewWriter ) => {
                const textarea = viewWriter.createEmptyElement( 'textarea', {
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId(),
                    'placeholder': modelElement.getAttribute('placeholder') || ''
                } );
                return textarea;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'textArea',
            view: ( modelElement, viewWriter ) => {
                const textarea = viewWriter.createEmptyElement( 'textarea', {
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId(),
                    'placeholder': modelElement.getAttribute('placeholder') || ''
                } );
                return toWidget( textarea, viewWriter );
            }
        } );

        // <fileUpload> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'input',
                classes: [ 'bz-optional-magic-field' ],
                attributes: {
                    'type': 'file',
                }
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'fileUpload', {
                    'data-bz-retained': viewElement.getAttribute('data-bz-retained') || this._nextRetainedDataId(),
                    'data-bz-share-release': viewElement.getAttribute('data-bz-share-release') || '',
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'fileUpload',
            view: ( modelElement, viewWriter ) => {
                const input = viewWriter.createEmptyElement( 'input', {
                    'type': 'file',
                    'class': 'bz-optional-magic-field',
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId(),
                    'data-bz-share-release': modelElement.getAttribute('data-bz-share-release') || '',
                } );
                return input;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'fileUpload',
            view: ( modelElement, viewWriter ) => {
                const input = viewWriter.createEmptyElement( 'input', {
                    'type': 'file',
                    'class': 'bz-optional-magic-field',
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId(),
                    'data-bz-share-release': modelElement.getAttribute('data-bz-share-release') || '',
                } );
                return toWidget( input, viewWriter );
            }
        } );

        // <slider> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'input',
                attributes: {
                    'type': 'range',
                }
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'slider', {
                    'class': viewElement.getAttribute('class') || '',
                    'data-bz-retained': viewElement.getAttribute('data-bz-retained') || this._nextRetainedDataId(),
                    'min': viewElement.getAttribute('min') || 0,
                    'max': viewElement.getAttribute('max') || 10,
                    'step': viewElement.getAttribute('step') || 1,
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'slider',
            view: ( modelElement, viewWriter ) => {
                const input = viewWriter.createEmptyElement( 'input', {
                    'type': 'range',
                    'class': modelElement.getAttribute('class') || '',
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId(),
                    'min': modelElement.getAttribute('min') || 0,
                    'max': modelElement.getAttribute('max') || 10, 
                    'step': modelElement.getAttribute('step') || 1,
                } );
                return input;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'slider',
            view: ( modelElement, viewWriter ) => {
                const input = viewWriter.createEmptyElement( 'input', {
                    'type': 'range',
                    'class': modelElement.getAttribute('class') || '',
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId(),
                    'min': modelElement.getAttribute('min') || 0,
                    'max': modelElement.getAttribute('max') || 10,
                    'step': modelElement.getAttribute('step') || 1,
                } );
                return toWidget( input, viewWriter );
            }
        } );

        // <select> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'select',
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'select', {
                    'data-bz-retained': viewElement.getAttribute('data-bz-retained') || this._nextRetainedDataId(),
                    'name': viewElement.getAttribute('name'),
                    'id': viewElement.getAttribute('id')
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'select',
            view: ( modelElement, viewWriter ) => {
                const select = viewWriter.createContainerElement( 'select', {
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId(),
                    'name': modelElement.getAttribute('name'),
                    'id': modelElement.getAttribute('id'),
                } );
                return select;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'select',
            view: ( modelElement, viewWriter ) => {
                const select = viewWriter.createContainerElement( 'select', {
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId(),
                    'name': modelElement.getAttribute('name'),
                    'id': modelElement.getAttribute('id')
                } );
                return toWidget( select, viewWriter );
            }
        } );

        // <selectOption> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'option',
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'selectOption', {
                    'value': viewElement.getAttribute('value'),
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'selectOption',
            view: ( modelElement, viewWriter ) => {
                const option = viewWriter.createContainerElement( 'option', {
                    'value': modelElement.getAttribute('value'),
                } );
                return option;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'selectOption',
            view: ( modelElement, viewWriter ) => {
                const option = viewWriter.createContainerElement( 'option', {
                    'value': modelElement.getAttribute('value'),
                } );
                return toWidget( option, viewWriter );
            }
        } );
    }
}
