import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { enablePlaceholder } from '@ckeditor/ckeditor5-engine/src/view/placeholder';
import { toWidget, toWidgetEditable } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';
import List from '@ckeditor/ckeditor5-list/src/list';
import InsertIndustrySelectorCommand from './insertindustryselectorcommand';
import InsertTextInputCommand from './inserttextinputcommand';
import InsertFileUploadCommand from './insertfileuploadcommand';
import InsertTextAreaQuestionCommand from './inserttextareaquestioncommand';
import InsertTextAreaCommand from './inserttextareacommand';
import { getNamedChildOrSibling } from './utils';

export default class ContentCommonEditing extends Plugin {
    static get requires() {
        return [ Widget, List ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();

        // Individial elements.
        this.editor.commands.add( 'insertTextInput', new InsertTextInputCommand( this.editor ) );
        this.editor.commands.add( 'insertTextArea', new InsertTextAreaCommand( this.editor ) );
        this.editor.commands.add( 'insertIndustrySelector', new InsertIndustrySelectorCommand( this.editor ) );
        // Blocks.
        this.editor.commands.add( 'insertFileUpload', new InsertFileUploadCommand( this.editor ) );
    }

    _defineSchema() {
        const schema = this.editor.model.schema;

        // Shared elements.
        schema.register( 'questionFieldset', {
            isLimit: true,
            isObject: true,
            allowIn: '$root',
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
            allowAttributes: [ 'type', 'placeholder', 'data-bz-retained' ],
            allowIn: [ '$root', '$block', 'questionFieldset', 'industrySelectorContainer' ],
        } );

        schema.register( 'textArea', {
            isObject: true,
            allowAttributes: [ 'placeholder' , 'aria-labelledby'],
            allowIn: [ '$root', '$block', 'checkboxDiv', 'radioDiv', 'questionFieldset' ],
        } );

        schema.register( 'fileUpload', {
            isObject: true,
            allowAttributes: [ 'type' ],
            allowIn: [ '$root', 'questionFieldset' ],
        } );

        schema.register( 'select', {
            isObject: true,
            allowAttributes: [ 'id', 'name', 'data-bz-retained' ],
            allowIn: [ 'questionFieldset', 'industrySelectorContainer' ],
        } );

        schema.register( 'selectOption', {
            isObject: true,
            allowAttributes: [ 'value', 'selected' ],
            allowIn: [ 'select' ],
            allowContentOf: '$block'
        } );

        schema.register( 'industrySelectorContainer', {
            isObject: true,
            allowIn: '$root',
            allowContentOf: [ '$root', 'select', 'textInput' ],
        });
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
            model: ( viewElement, { writer } ) => {
                // Only include the class attribute if it's set.
                const classes = viewElement.getAttribute('class');
                const attrs = classes ? { 'class': classes } : {};
                return writer.createElement( 'questionFieldset', attrs );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'questionFieldset',
            view: ( modelElement, { writer } ) => {
                // Only include the class attribute if it's set.
                const classes = modelElement.getAttribute('class');
                const attrs = classes ? { 'class': classes } : {};
                return writer.createEditableElement( 'fieldset', attrs );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'questionFieldset',
            view: ( modelElement, { writer } ) => {
                // Only include the class attribute if it's set.
                const classes = modelElement.getAttribute('class');
                const attrs = classes ? { 'class': classes } : {};
                const fieldset = writer.createContainerElement( 'fieldset', attrs );
                return toWidget( fieldset, writer );
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
            view: ( modelElement, { writer } ) => {
                const legend = writer.createEditableElement( 'legend' );

                enablePlaceholder( {
                    view: editing.view,
                    element: legend,
                    text: 'Legend'
                } );

                return toWidgetEditable( legend, writer );
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
            model: ( viewElement, { writer } ) => {
                return writer.createElement( 'textInput', {
                    'data-bz-retained': viewElement.getAttribute('data-bz-retained'),
                    'placeholder': viewElement.getAttribute('placeholder') || '',
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'textInput',
            view: ( modelElement, { writer } ) => {
                const input = writer.createEmptyElement( 'input', {
                    'type': 'text',
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained'),
                    'placeholder': modelElement.getAttribute('placeholder') || '',
                } );
                return input;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'textInput',
            view: ( modelElement, { writer } ) => {
                // Note: using a ContainerElement because toWidget can only run on ContainerElements
                const input = writer.createContainerElement( 'input', {
                    'type': 'text',
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained'),
                    'placeholder': modelElement.getAttribute('placeholder') || '',
                } );
                return toWidget( input, writer );
            }
        } );

        // <textArea> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'textarea',
            },
            model: ( viewElement, { writer } ) => {
                let arialLabelledBy = ''
                const textareaLabel =  getNamedChildOrSibling('div', viewElement.parent)
                if(textareaLabel) {
                    arialLabelledBy = textareaLabel.getAttribute('id');
                }
                
                return writer.createElement( 'textArea', {
                    'data-bz-retained': viewElement.getAttribute('data-bz-retained'),
                    'placeholder': viewElement.getAttribute('placeholder') || '',
                    'aria-labelledby': arialLabelledBy,
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'textArea',
            view: ( modelElement, { writer } ) => {
                let arialLabelledBy = ''
                const textareaLabel =  getNamedChildOrSibling('textareaLabel', modelElement.parent)
                if(textareaLabel) {
                    arialLabelledBy = textareaLabel.getAttribute('id');
                }
                const textarea = writer.createEmptyElement( 'textarea', {
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained'),
                    'placeholder': modelElement.getAttribute('placeholder') || '',
                    'aria-labelledby': arialLabelledBy,
                } );
                return textarea;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'textArea',
            view: ( modelElement, { writer } ) => {
                let arialLabelledBy = ''
                const textareaLabel =  getNamedChildOrSibling('textareaLabel', modelElement.parent)
                if(textareaLabel) {
                    arialLabelledBy = textareaLabel.getAttribute('id');
                }
                const textarea = writer.createContainerElement( 'textarea', {
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained'),
                    'placeholder': modelElement.getAttribute('placeholder') || '',
                    'aria-labelledby': arialLabelledBy,
                } );
                return toWidget( textarea, writer );
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
            model: ( viewElement, { writer } ) => {
                return writer.createElement( 'fileUpload', {
                    'data-bz-retained': viewElement.getAttribute('data-bz-retained'),
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'fileUpload',
            view: ( modelElement, { writer } ) => {
                const input = writer.createEmptyElement( 'input', {
                    'type': 'file',
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained'),
                } );
                return input;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'fileUpload',
            view: ( modelElement, { writer } ) => {
                // Note: using a ContainerElement because toWidget can only run on ContainerElements
                const input = writer.createContainerElement( 'input', {
                    'type': 'file',
                    'disabled': '',
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained'),
                } );
                return toWidget( input, writer, {'label': 'test'} );
            }
        } );

        // <select> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'select',
            },
            model: ( viewElement, { writer } ) => {
                return writer.createElement( 'select', {
                    'data-bz-retained': viewElement.getAttribute('data-bz-retained'),
                    'name': viewElement.getAttribute('name'),
                    'id': viewElement.getAttribute('id'),
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'select',
            view: ( modelElement, { writer } ) => {
                const select = writer.createContainerElement( 'select', {
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained'),
                    'name': modelElement.getAttribute('name'),
                    'id': modelElement.getAttribute('id'),
                } );
                return select;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'select',
            view: ( modelElement, { writer } ) => {
                // Note: using a ContainerElement because toWidget can only run on ContainerElements
                const select = writer.createContainerElement( 'select', {
                    'data-bz-retained': modelElement.getAttribute('data-bz-retained'),
                    'name': modelElement.getAttribute('name'),
                    'id': modelElement.getAttribute('id'),
                } );
                return toWidget( select, writer );
            }
        } );

        // <selectOption> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'option',
            },
            model: ( viewElement, { writer } ) => {
                return writer.createElement( 'selectOption', {
                    'value': viewElement.getAttribute('value'),
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'selectOption',
            view: ( modelElement, { writer } ) => {
                const option = writer.createContainerElement( 'option', {
                    'value': modelElement.getAttribute('value'),
                } );
                return option;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'selectOption',
            view: ( modelElement, { writer } ) => {
                const option = writer.createContainerElement( 'option', {
                    'value': modelElement.getAttribute('value'),
                } );
                return toWidget( option, writer );
            }
        } );

        // <industrySelectorContainer> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'div',
                classes: 'industry-selector-container',
            },
            model: 'industrySelectorContainer',
        } );
        conversion.for( 'downcast' ).elementToElement( {
            model: 'industrySelectorContainer',
            view: {
                name: 'div',
                classes: 'industry-selector-container',
            },
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
