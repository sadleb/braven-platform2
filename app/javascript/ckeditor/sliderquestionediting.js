import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { toWidget } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';
import InsertSliderQuestionCommand from './insertsliderquestioncommand';

export default class SliderQuestionEditing extends Plugin {
    static get requires() {
        return [ Widget ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();

        this.editor.commands.add( 'insertSliderQuestion', new InsertSliderQuestionCommand( this.editor ) );
    }

    _defineSchema() {
        const schema = this.editor.model.schema;

        schema.register( 'sliderQuestion', {
            isObject: true,
            allowIn: 'section',
        } );

        schema.register( 'displayValueDiv', {
            isObject: true,
            allowIn: 'questionFieldset',
        } );

        schema.register( 'currentValueSpan', {
            isObject: true,
            allowIn: 'displayValueDiv',
        } );

        schema.extend( 'question', {
            allowIn: 'sliderQuestion'
        } );

        schema.extend( 'answer', {
            allowIn: 'sliderQuestion'
        } );

        schema.extend( 'slider', {
            allowIn: 'questionFieldset'
        } );
    }

    _defineConverters() {
        const editor = this.editor;
        const conversion = editor.conversion;
        const { editing, data, model } = editor;

        // <sliderQuestion> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'div',
                classes: ['module-block', 'module-block-range']
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'sliderQuestion', {} );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'sliderQuestion',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createContainerElement( 'div', {
                    'class': 'module-block module-block-range',
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'sliderQuestion',
            view: ( modelElement, viewWriter ) => {
                const sliderQuestion = viewWriter.createContainerElement( 'div', {
                    'class': 'module-block module-block-range',
                } );

                return toWidget( sliderQuestion, viewWriter, { label: 'range question widget' } );
            }
        } );

        // <displayValueDiv> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'div',
                classes: ['display-value']
            },
            model: 'displayValueDiv'
        } );
        conversion.for( 'downcast' ).elementToElement( {
            model: 'displayValueDiv',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createContainerElement( 'div', {
                    'class': 'display-value',
                } );
            }
        } );

        // <currentValueSpan> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'span',
                classes: ['current-value']
            },
            model: 'currentValueSpan'
        } );
        conversion.for( 'downcast' ).elementToElement( {
            model: 'currentValueSpan',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createEmptyElement( 'span', {
                    'class': 'current-value',
                } );
            }
        } );
    }
}
