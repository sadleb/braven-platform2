import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { enablePlaceholder } from '@ckeditor/ckeditor5-engine/src/view/placeholder';
import { toWidget, toWidgetEditable } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';
import List from '@ckeditor/ckeditor5-list/src/list';
import InsertIndustrySelectorCommand from './insertindustryselectorcommand';
import InsertNumericalSelectorCommand from './insertnumericalselectorcommand';
import InsertTextInputCommand from './inserttextinputcommand';
import InsertTextAreaCommand from './inserttextareacommand';
import { getNamedChildOrSibling } from './utils';

export default class ContentCommonEditing extends Plugin {
    static get requires() {
        return [ Widget, List ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();

        this.editor.commands.add( 'insertTextInput', new InsertTextInputCommand( this.editor ) );
        this.editor.commands.add( 'insertTextArea', new InsertTextAreaCommand( this.editor ) );
        this.editor.commands.add( 'insertIndustrySelector', new InsertIndustrySelectorCommand( this.editor ) );
        this.editor.commands.add( 'insertNumericalSelector', new InsertNumericalSelectorCommand( this.editor) );

        // Reminder: when adding a new element with unique `name` or `id`, be sure to look at
        // inputuniqueattributeediting.js too!
    }

    _defineSchema() {
        const schema = this.editor.model.schema;

        // Shared elements.

        // <fieldset> is used by both radio groups and industry selector.
        schema.register( 'fieldset', {
            isObject: true,
            allowIn: '$root',
            allowAttributes: [ 'data-radio-group' ],
            allowContentOf: '$root',
        } );

        schema.register( 'legend', {
            isLimit: true,
            allowIn: 'fieldset',
            allowContentOf: '$block'
        } );

        // Shared inputs.
        schema.register( 'textInput', {
            isObject: true,
            allowAttributes: [ 'type', 'placeholder', 'aria-label', 'name' ],
            allowIn: [ '$root' ],
        } );

        schema.register( 'textArea', {
            isObject: true,
            allowAttributes: [ 'placeholder', 'aria-label', 'name' ],
            allowIn: [ '$root' ],
        } );

        /**
         * Example valid structure:
         *
         * <selectWrapper>
         *   <selectLabel for="select-id">$text</selectLabel>
         *   <select id="select-id" name="select-name">
         *     <selectOption value="value-1">$text</selectOption>
         *     <selectOption value="value-2">$text</selectOption>
         *   </select>
         * </selectWrapper>
         */
        schema.register( 'selectWrapper',  {
            isObject: true,
            allowIn: [ '$root' ],
        } );

        schema.register( 'selectLabel', {
            isLimit: true,
            isInline: true,
            allowAttributes: [ 'for' ],
            allowIn: [ 'selectWrapper' ],
            allowContentOf: '$block',
        } );

        schema.register( 'select', {
            isInline: true,
            allowAttributes: [ 'name', 'id' ],
            allowIn: [ 'selectWrapper' ],
        } );

        schema.register( 'selectOption', {
            allowAttributes: [ 'value', 'selected' ],
            allowIn: [ 'select' ],
            allowContentOf: '$block',
        } );
    }

    _defineConverters() {
        const editor = this.editor;
        const conversion = editor.conversion;
        const { editing, data, model } = editor;

        // <fieldset> converters
        // fieldsets should have a data-radio-group iff they contain radio buttons.
        // The industry selector feature uses fieldsets too, without that attribute.
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'fieldset'
            },
            model: ( viewElement, { writer } ) => {
                let attributes = {};
                const radioGroup = viewElement.getAttribute( 'data-radio-group' );
                if ( radioGroup ) {
                    attributes['data-radio-group'] = radioGroup;
                }
                return writer.createElement( 'fieldset', attributes );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'fieldset',
            view: ( modelElement, { writer } ) => {
                let attributes = {};
                const radioGroup = modelElement.getAttribute( 'data-radio-group' );
                if ( radioGroup ) {
                    attributes['data-radio-group'] = radioGroup;
                }
                return writer.createEditableElement( 'fieldset', attributes );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'fieldset',
            view: ( modelElement, { writer } ) => {
                let attributes = {};
                const radioGroup = modelElement.getAttribute( 'data-radio-group' );
                if ( radioGroup ) {
                    attributes['data-radio-group'] = radioGroup;
                }
                const fieldset = writer.createContainerElement( 'fieldset', attributes );
                return toWidget( fieldset, writer, {
                    'label': 'fieldset',
                    'hasSelectionHandle': true,
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
                    'name': viewElement.getAttribute('name'),
                    'placeholder': viewElement.getAttribute('placeholder') || '',
                    'aria-label': viewElement.getAttribute('aria-label') || '',
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'textInput',
            view: ( modelElement, { writer } ) => {
                const input = writer.createEmptyElement( 'input', {
                    'type': 'text',
                    'name': modelElement.getAttribute('name'),
                    'placeholder': modelElement.getAttribute('placeholder') || '',
                    'aria-label': modelElement.getAttribute('aria-label') || '',
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
                    'name': modelElement.getAttribute('name'),
                    'placeholder': modelElement.getAttribute('placeholder') || '',
                    'aria-label': modelElement.getAttribute('aria-label') || '',
                } );
                return toWidget( input, writer, { 'label': 'text input' } );
            }
        } );

        // <textArea> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'textarea',
            },
            model: ( viewElement, { writer } ) => {
                return writer.createElement( 'textArea', {
                    'name': viewElement.getAttribute('name'),
                    'placeholder': viewElement.getAttribute('placeholder') || '',
                    'aria-label': viewElement.getAttribute('aria-label') || '',
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'textArea',
            view: ( modelElement, { writer } ) => {
                const textarea = writer.createEmptyElement( 'textarea', {
                    'name': modelElement.getAttribute('name'),
                    'placeholder': modelElement.getAttribute('placeholder') || '',
                    'aria-label': modelElement.getAttribute('aria-label') || '',
                } );
                return textarea;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'textArea',
            view: ( modelElement, { writer } ) => {
                // Note: using a ContainerElement because toWidget can only run on ContainerElements
                const textarea = writer.createContainerElement( 'textarea', {
                    'name': modelElement.getAttribute('name'),
                    'placeholder': modelElement.getAttribute('placeholder') || '',
                    'aria-label': modelElement.getAttribute('aria-label') || '',
                } );
                return toWidget( textarea, writer, { 'label': 'textarea' } );
            }
        } );

        // Dropdown elements
        // Note: There are custom clipboard handlers for these in
        // inputuniqueattributeediting.js.

        // <selectWrapper> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'div',
                classes: [ 'select-wrapper' ],
            },
            model: 'selectWrapper',
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'selectWrapper',
            view: {
                name: 'div',
                classes: [ 'select-wrapper' ],
            },
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'selectWrapper',
            view: ( modelElement, { writer } ) => {
                const div = writer.createContainerElement( 'div', {
                    'class': 'select-wrapper',
                } );
                return toWidget( div, writer, {
                    'label': 'dropdown wrapper',
                    'hasSelectionHandle': true,
                } );
            }
        } );

        // <selectLabel> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'label',
                classes: [ 'select-label' ],
            },
            model: ( viewElement, { writer } ) => {
                return writer.createElement( 'selectLabel', {
                    // HACK: Get the id of the select this label corresponds to.
                    'for': viewElement.parent.getChild(1).getAttribute('id')
                } );
            }

        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'selectLabel',
            view: ( modelElement, { writer } ) => {
                return writer.createContainerElement( 'label', {
                    // HACK: Get the id of the select this label corresponds to.
                    'for': modelElement.parent.getChild(1).getAttribute('id'),
                    'class': 'select-label',
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'selectLabel',
            view: ( modelElement, { writer } ) => {
                const label = writer.createEditableElement( 'label', {
                    // NOTE: We don't set the 'for' attribute in the editing view, so that clicking in the label
                    // editable to type doesn't also toggle the select.
                    'class': 'select-label',
                } );

                enablePlaceholder( {
                    view: editing.view,
                    element: label,
                    text: 'Dropdown label'
                } );

                return toWidgetEditable( label, writer, { 'label': 'dropdown label' } );
            }
        } );

        // <select> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'select',
            },
            model: ( viewElement, { writer } ) => {
                return writer.createElement( 'select', {
                    'id': viewElement.getAttribute('id'),
                    'name': viewElement.getAttribute('name'),
                } );
            }
        } );
        conversion.for( 'downcast' ).elementToElement( {
            model: 'select',
            view: ( modelElement, { writer } ) => {
                const select = writer.createContainerElement( 'select', {
                    'id': modelElement.getAttribute('id'),
                    'name': modelElement.getAttribute('name'),
                } );
                return select;
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
        conversion.for( 'downcast' ).elementToElement( {
            model: 'selectOption',
            view: ( modelElement, { writer } ) => {
                const option = writer.createContainerElement( 'option', {
                    'value': modelElement.getAttribute('value'),
                } );
                return option;
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
        conversion.attributeToAttribute( { model: 'aria-label', view: 'aria-label' } );
    }
}
