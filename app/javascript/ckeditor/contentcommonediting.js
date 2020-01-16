import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { enablePlaceholder } from '@ckeditor/ckeditor5-engine/src/view/placeholder';
import { toWidget, toWidgetEditable } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';

import { setupCustomAttributeConversion } from './utils';

export default class ContentCommonEditing extends Plugin {
    static get requires() {
        return [ Widget ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();
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
            allowIn: 'question',
        } );

        schema.register( 'questionFieldset', {
            // Cannot be split or left by the caret.
            isLimit: true,
            allowIn: 'questionForm',
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
            allowAttributes: [ 'data-bz-retained', 'type' ],
            allowIn: '$root',
        } );

        schema.register( 'textArea', {
            isObject: true,
            allowAttributes: [ 'data-bz-retained' ],
            allowIn: [ '$root', 'checkboxDiv', 'radioDiv', 'tableCell', 'questionFieldset' ],
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
                return viewWriter.createContainerElement( 'div', { class: 'question' } );
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
                const h5 = viewWriter.createEmptyElement( 'h5', {} );

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
                    'data-bz-retained': viewElement.getAttribute('data-bz-retained'),
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'textInput',
            view: ( modelElement, viewWriter ) => {
                const input = viewWriter.createEmptyElement( 'input', {
                    'type': 'text',
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained'),
                } );
                return input;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'textInput',
            view: ( modelElement, viewWriter ) => {
                const input = viewWriter.createEmptyElement( 'input', {
                    'type': 'text',
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained'),
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
                    'data-bz-retained': viewElement.getAttribute('data-bz-retained'),
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'textArea',
            view: ( modelElement, viewWriter ) => {
                const textarea = viewWriter.createEmptyElement( 'textarea', {
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained'),
                } );
                return textarea;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'textArea',
            view: ( modelElement, viewWriter ) => {
                const textarea = viewWriter.createEmptyElement( 'textarea', {
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained'),
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
                    'data-bz-retained': viewElement.getAttribute('data-bz-retained'),
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
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained'),
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
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained'),
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
                    'data-bz-retained': viewElement.getAttribute('data-bz-retained'),
                    'min': viewElement.getAttribute('min'),
                    'max': viewElement.getAttribute('max'),
                    'step': viewElement.getAttribute('step') || '',
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'slider',
            view: ( modelElement, viewWriter ) => {
                const input = viewWriter.createEmptyElement( 'input', {
                    'type': 'range',
                    'class': modelElement.getAttribute('class') || '',
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained'),
                    'min': modelElement.getAttribute('min'),
                    'max': modelElement.getAttribute('max'),
                    'step': modelElement.getAttribute('step') || '',
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
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained'),
                    'min': modelElement.getAttribute('min'),
                    'max': modelElement.getAttribute('max'),
                    'step': modelElement.getAttribute('step') || '',
                } );
                return toWidget( input, viewWriter );
            }
        } );
    }
}
