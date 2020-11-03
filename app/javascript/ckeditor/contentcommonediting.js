import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { enablePlaceholder } from '@ckeditor/ckeditor5-engine/src/view/placeholder';
import { toWidget, toWidgetEditable } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';
import List from '@ckeditor/ckeditor5-list/src/list';
import Table from '@ckeditor/ckeditor5-table/src/table';
import RetainedData from './retaineddata';
import InsertTextInputCommand from './inserttextinputcommand';
import InsertFileUploadQuestionCommand from './insertfileuploadquestioncommand';
import InsertTextAreaQuestionCommand from './inserttextareaquestioncommand';
import InsertTextAreaCommand from './inserttextareacommand';
import SetAttributesCommand from './setattributescommand';
import { ALLOWED_ATTRIBUTES, filterAllowedAttributes } from './customelementattributepreservation';
import { getNamedChildOrSibling } from './utils';

export default class ContentCommonEditing extends Plugin {
    static get requires() {
        return [ Widget, RetainedData, List, Table ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();

        // Individial elements.
        this.editor.commands.add( 'insertTextInput', new InsertTextInputCommand( this.editor ) );
        this.editor.commands.add( 'insertTextArea', new InsertTextAreaCommand( this.editor ) );
        // Blocks.
        this.editor.commands.add( 'insertFileUploadQuestion', new InsertFileUploadQuestionCommand( this.editor ) );
        // SetAttributes.
        this.editor.commands.add( 'setAttributes', new SetAttributesCommand( this.editor ) );

        // Add a shortcut to the retained data ID function.
        this._nextRetainedDataId = this.editor.plugins.get('RetainedData').getNextId;
        this._nextId = this.editor.plugins.get('RetainedData').getNextCount;
    }

    /**
     * Example valid structures:
     *
     * <moduleBlock>
     *   <content>
     *     <contentTitle>$text</contentTitle>
     *     <contentBody>$block</contentBody>
     *     <doneButton/>
     *   </content>
     * </moduleBlock>
     *
     * <moduleBlock>
     *   <question>
     *     <questionTitle>$text</questionTitle>
     *     <questionBody>$block</questionBody>
     *     <questionForm>
     *       <questionFieldset>
     *         ...inputs...
     *       </questionFieldset>
     *       <doneButton/>
     *     </questionForm>
     *   </question>
     *   <answer>
     *     <answerTitle>$text</answerTitle>
     *     <answerBody>$block</answerBody>
     *   </answer>
     * </moduleBlock>
     */
    _defineSchema() {
        const schema = this.editor.model.schema;

        // Shared elements.
        schema.register( 'questionFieldset', {
            isLimit: true,
            allowIn: 'questionForm',
        } );

        // Matrix question table.
        schema.register( 'legend', {
            isLimit: true,
            allowIn: 'questionFieldset',
            allowContentOf: '$block'
        } );

        // Shared inputs.
        schema.register( 'textInput', {
            isObject: true,
            allowAttributes: [ 'type', 'placeholder' ].concat(ALLOWED_ATTRIBUTES),
            allowIn: [ '$root', '$block', 'tableCell', 'questionFieldset' ],
        } );

        schema.register( 'textArea', {
            isObject: true,
            allowAttributes: [ 'placeholder' , 'aria-labelledby'].concat(ALLOWED_ATTRIBUTES),
            allowIn: [ '$root', '$block', 'checkboxDiv', 'radioDiv', 'tableCell', 'questionFieldset' ],
        } );

        schema.register( 'fileUpload', {
            isObject: true,
            allowAttributes: [ 'type' ].concat(ALLOWED_ATTRIBUTES),
            allowIn: [ '$root', 'questionFieldset' ],
        } );

        schema.register( 'select', {
            isObject: true,
            allowAttributes: [ 'id', 'name' ].concat(ALLOWED_ATTRIBUTES),
            allowIn: [ '$root', 'questionFieldset' ],
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

        // <questionFieldset> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'fieldset'
            },
            model: ( viewElement, modelWriter ) => {
                // Only include the class attribute if it's set.
                const classes = viewElement.getAttribute('class');
                const attrs = classes ? { 'class': classes } : {};
                return modelWriter.createElement( 'questionFieldset', attrs );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'questionFieldset',
            view: ( modelElement, viewWriter ) => {
                // Only include the class attribute if it's set.
                const classes = modelElement.getAttribute('class');
                const attrs = classes ? { 'class': classes } : {};
                return viewWriter.createEditableElement( 'fieldset', attrs );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'questionFieldset',
            view: ( modelElement, viewWriter ) => {
                // Only include the class attribute if it's set.
                const classes = modelElement.getAttribute('class');
                const attrs = classes ? { 'class': classes } : {};
                return viewWriter.createContainerElement( 'fieldset', attrs );
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
                return modelWriter.createElement( 'textInput', new Map( [
                    ...filterAllowedAttributes(viewElement.getAttributes()),
                    ['data-bz-retained', viewElement.getAttribute('data-bz-retained') || this._nextRetainedDataId()],
                    ['placeholder', viewElement.getAttribute('placeholder') || ''],
                ] ) );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'textInput',
            view: ( modelElement, viewWriter ) => {
                const input = viewWriter.createEmptyElement( 'input', new Map( [
                    ...filterAllowedAttributes(modelElement.getAttributes()),
                    [ 'type', 'text' ],
                    [ 'data-bz-retained', modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId() ],
                    [ 'placeholder', modelElement.getAttribute('placeholder') || '' ],
                ] ) );
                return input;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'textInput',
            view: ( modelElement, viewWriter ) => {
                const input = viewWriter.createEmptyElement( 'input', new Map( [
                    ...filterAllowedAttributes(modelElement.getAttributes()),
                    [ 'type', 'text' ],
                    [ 'data-bz-retained', modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId() ],
                    [ 'placeholder', modelElement.getAttribute('placeholder') || '' ],
                ] ) );
                return toWidget( input, viewWriter );
            }
        } );

        // <textArea> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'textarea',
            },
            model: ( viewElement, modelWriter ) => {
                let arialLabelledBy = ''
                const textareaLabel =  getNamedChildOrSibling('div', viewElement.parent)
                if(textareaLabel) {
                    arialLabelledBy = textareaLabel.getAttribute('id');
                }
                
                return modelWriter.createElement( 'textArea', new Map( [
                    ...filterAllowedAttributes(viewElement.getAttributes()),
                    [ 'data-bz-retained', viewElement.getAttribute('data-bz-retained') || this._nextRetainedDataId() ],
                    [ 'placeholder', viewElement.getAttribute('placeholder') || '' ],
                    [ 'aria-labelledby', arialLabelledBy ]
                ] ) );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'textArea',
            view: ( modelElement, viewWriter ) => {
                let arialLabelledBy = ''
                const textareaLabel =  getNamedChildOrSibling('textareaLabel', modelElement.parent)
                if(textareaLabel) {
                    arialLabelledBy = textareaLabel.getAttribute('id');
                }
                const textarea = viewWriter.createEmptyElement( 'textarea', new Map( [
                    ...filterAllowedAttributes(modelElement.getAttributes()),
                    [ 'data-bz-retained', modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId() ],
                    [ 'placeholder', modelElement.getAttribute('placeholder') || '' ],
                    [ 'aria-labelledby', arialLabelledBy ]
                ] ) );
                return textarea;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'textArea',
            view: ( modelElement, viewWriter ) => {
                let arialLabelledBy = ''
                const textareaLabel =  getNamedChildOrSibling('textareaLabel', modelElement.parent)
                if(textareaLabel) {
                    arialLabelledBy = textareaLabel.getAttribute('id');
                }
                const textarea = viewWriter.createEmptyElement( 'textarea', new Map( [
                    ...filterAllowedAttributes(modelElement.getAttributes()),
                    [ 'data-bz-retained', modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId() ],
                    [ 'placeholder', modelElement.getAttribute('placeholder') || '' ],
                    [ 'aria-labelledby', arialLabelledBy ]
                ] ) );
                return toWidget( textarea, viewWriter );
            }
        } );

        // <fileUpload> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'input',
                attributes: {
                    'type': 'file',
                }
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'fileUpload', new Map( [
                    ...filterAllowedAttributes(viewElement.getAttributes()),
                    [ 'data-bz-retained', viewElement.getAttribute('data-bz-retained') || this._nextRetainedDataId() ],
                ] ) );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'fileUpload',
            view: ( modelElement, viewWriter ) => {
                const input = viewWriter.createEmptyElement( 'input', new Map( [
                    ...filterAllowedAttributes(modelElement.getAttributes()),
                    [ 'type', 'file' ],
                    [ 'data-bz-retained', modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId() ],
                ] ) );
                return input;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'fileUpload',
            view: ( modelElement, viewWriter ) => {
                const input = viewWriter.createEmptyElement( 'input', new Map( [
                    ...filterAllowedAttributes(modelElement.getAttributes()),
                    [ 'type', 'file' ],
                    [ 'disabled', '' ],
                    [ 'data-bz-retained', modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId() ],
                ] ) );
                return toWidget( input, viewWriter );
            }
        } );

        // <select> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'select',
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'select', new Map( [
                    ...filterAllowedAttributes(viewElement.getAttributes()),
                    [ 'data-bz-retained', viewElement.getAttribute('data-bz-retained') || this._nextRetainedDataId() ],
                    [ 'name', viewElement.getAttribute('name') ],
                    [ 'id', viewElement.getAttribute('id') ],
                ] ) );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'select',
            view: ( modelElement, viewWriter ) => {
                const select = viewWriter.createContainerElement( 'select', new Map( [
                    ...filterAllowedAttributes(modelElement.getAttributes()),
                    [ 'data-bz-retained', modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId() ],
                    [ 'name', modelElement.getAttribute('name') ],
                    [ 'id', modelElement.getAttribute('id') ],
                ] ) );
                return select;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'select',
            view: ( modelElement, viewWriter ) => {
                const select = viewWriter.createContainerElement( 'select', new Map( [
                    ...filterAllowedAttributes(modelElement.getAttributes()),
                    [ 'data-bz-retained', modelElement.getAttribute('data-bz-retained') || this._nextRetainedDataId() ],
                    [ 'name', modelElement.getAttribute('name') ],
                    [ 'id', modelElement.getAttribute('id') ],
                ] ) );
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

        // Shared attribute converters.
        // We must explicitly define an attributeToAttribute converter in order to live-update
        // model changes in the editingView when changing it from the setAttributes command.
        // This is because elementToElement is only called once when the element is inserted,
        // NOT when attributes are changed/added/removed.
        // See https://github.com/ckeditor/ckeditor5/issues/6308#issuecomment-590243325
        // and https://ckeditor.com/docs/ckeditor5/latest/api/module_engine_conversion_conversion-Conversion.html#function-attributeToAttribute
        conversion.attributeToAttribute( { model: 'placeholder', view: 'placeholder' } );
        conversion.attributeToAttribute( { model: 'src', view: 'src' } );
    }
}
