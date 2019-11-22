import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
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
    }

    _defineSchema() {
        const schema = this.editor.model.schema;

        schema.register( 'radioQuestion', {
            // Behaves like a self-contained object (e.g. an image).
            isObject: true,

            // Allow in places where other blocks are allowed (e.g. directly in the root).
            allowIn: 'section',

            // Each content part preview has an ID. A unique ID tells the application which
            // radio-question it represents and makes it possible to render it inside a widget.
            allowAttributes: [ 'id' ]
        } );

        schema.register( 'rqQuestion', {
            // Behaves like a self-contained object (e.g. an image).
            isObject: true,

            allowIn: 'radioQuestion',
        } );

        schema.register( 'rqQuestionTitle', {
            // Cannot be split or left by the caret.
            isLimit: true,

            allowIn: 'rqQuestion',

            // Allow content which is allowed in blocks (i.e. text with attributes).
            allowContentOf: '$block'
        } );

        schema.register( 'rqQuestionForm', {
            // Cannot be split or left by the caret.
            isLimit: true,

            allowIn: 'rqQuestion',

            // Allow content which is allowed in the root (e.g. paragraphs).
            allowContentOf: ['rqQuestionFieldset'],
        } );

        schema.register( 'rqQuestionFieldset', {
            // Cannot be split or left by the caret.
            isLimit: true,

            allowIn: 'rqQuestionForm',

            // Allow content which is allowed in the root (e.g. paragraphs).
            //allowContentOf: ['rqQuestionLegend', 'radio'],
        } );

        schema.register( 'rqQuestionLegend', {
            // Cannot be split or left by the caret.
            isLimit: true,

            allowIn: 'rqQuestionFieldset',

            // Allow content which is allowed in blocks (i.e. text with attributes).
            allowContentOf: '$block'
        } );

        schema.register( 'radioDiv', {
            // Cannot be split or left by the caret.
            //isLimit: true,

            allowIn: 'rqQuestionFieldset',
            //allowIn: 'section',

            // Allow content which is allowed in blocks (i.e. text with attributes).
            allowContentOf: '$root',
        } );

        schema.register( 'radioInput', {
            // Cannot be split or left by the caret.
            //isLimit: true,
            isInline: true,

            allowIn: 'radioDiv',

            // Allow content which is allowed in blocks (i.e. text with attributes).
            //allowContentOf: '$block',

            allowAttributes: [ 'id', 'name', 'value' ]
        } );

        schema.register( 'radioLabel', {
            // Cannot be split or left by the caret.
            //isLimit: true,
            isInline: true,

            allowIn: 'radioDiv',

            // Allow content which is allowed in blocks (i.e. text with attributes).
            allowContentOf: '$block',

            allowAttributes: [ 'for' ]
        } );

        schema.register( 'rqAnswer', {
            // Behaves like a self-contained object (e.g. an image).
            isObject: true,

            allowIn: 'radioQuestion'
        } );

        schema.register( 'rqAnswerTitle', {
            // Cannot be split or left by the caret.
            isLimit: true,

            allowIn: 'rqAnswer',

            // Allow content which is allowed in blocks (i.e. text with attributes).
            allowContentOf: '$block'
        } );

        schema.register( 'rqAnswerText', {
            // Cannot be split or left by the caret.
            isLimit: true,

            allowIn: 'rqAnswer',

            // Allow content which is allowed in the root (e.g. paragraphs).
            allowContentOf: '$root'
        } );

        schema.addChildCheck( ( context, childDefinition ) => {
            // Note that the context is automatically normalized to a SchemaContext instance and
            // the child to its definition (SchemaCompiledItemDefinition).

            // If checkChild() is called with a context that ends with blockQuote and blockQuote as a child
            // to check, make the checkChild() method return false.
            if ( context.endsWith( 'rqAnswerText' ) && childDefinition.name == 'radioQuestion' ) {
                return false;
            }
        } );
    }

    _defineConverters() {
        const editor = this.editor;
        const conversion = editor.conversion;
        const { editing, data, model } = editor;

        /*
        editor.commands.get( 'enter' ).on( 'execute', (evt, data, three, four) => {
	    const positionParent = editor.model.document.selection.getLastPosition().parent;
	    if ( positionParent.name == 'radioLabel' ) {
                editor.model.change( writer => {
                        console.log('enter>>>>>>>>>>>');
                        console.log(writer, positionParent);
                        console.log(evt, data, three, four);
                        console.log('enter<<<<<<<<<<<');
                        //alert('omg');

                        editor.execute( 'insertRadio')

const fieldset = positionParent.parent.parent;


    const radioDiv = writer.createElement( 'radioDiv' );
    const radioInput = writer.createElement( 'radioInput' );
    const radioLabel = writer.createElement( 'radioLabel' );

    writer.append( radioInput, radioDiv );
    writer.append( radioLabel, radioDiv );

    //writer.insert( writer.createPositionAt( fieldset, 0 ), radioDiv );

    console.log(data);
				data.preventDefault();
				evt.stop();
                });
            }
        });
        */
        		this.listenTo( editing.view.document, 'enter', ( evt, data ) => {
			const doc = this.editor.model.document;
			const positionParent = doc.selection.getLastPosition().parent;
	                        if ( positionParent.name == 'radioLabel' ) {
			            alert('here');
                                    editor.execute( 'insertRadio')

				    data.preventDefault();
				    evt.stop();
	                	}
			});




        // <radioQuestion> converters ((data) view → model)
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'div',
                classes: ['module-block', 'module-block-radio']
            },
            model: ( viewElement, modelWriter ) => {
                // Read the "data-id" attribute from the view and set it as the "id" in the model.
                console.log(" up");
                return modelWriter.createElement( 'radioQuestion', {
                    id: parseInt( viewElement.getAttribute( 'data-id' ) )
                } );
            }
        } );

        // <radioQuestion> converters (model → data view)
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'radioQuestion',
            view: ( modelElement, viewWriter ) => {
                console.log("data down");
                return viewWriter.createEditableElement( 'div', {
                    class: 'module-block module-block-radio',
                    'data-id': modelElement.getAttribute( 'id' )
                } );
            }
        } );

        // <radioQuestion> converters (model → editing view)
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'radioQuestion',
            view: ( modelElement, viewWriter ) => {
                const id = modelElement.getAttribute( 'id' );
                console.log("ed down");

                const radioQuestion = viewWriter.createContainerElement( 'div', {
                    class: 'module-block module-block-radio',
                    'data-id': id
                } );

                //viewWriter.insert( viewWriter.createPositionAt( radioQuestion, 0 ), question );

                return toWidget( radioQuestion, viewWriter, { label: 'radio-question widget' } );
            }
        } );

        // <question> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'rqQuestion',
            view: {
                name: 'div',
                classes: 'rqQuestion'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'rqQuestion',
            view: {
                name: 'div',
                classes: 'rqQuestion'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'rqQuestion',
            view: ( modelElement, viewWriter ) => {
                const section = viewWriter.createContainerElement( 'div', { class: 'rqQuestion' } );

                return toWidget( section, viewWriter );
            }
        } );

        // <questionTitle> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'rqQuestionTitle',
            view: {
                name: 'h5'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'rqQuestionTitle',
            view: {
                name: 'h5'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'rqQuestionTitle',
            view: ( modelElement, viewWriter ) => {
                // Note: You use a more specialized createEditableElement() method here.
                const h5 = viewWriter.createEditableElement( 'h5', {
                } );

                return toWidgetEditable( h5, viewWriter );
            }
        } );

        // <questionForm> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'rqQuestionForm',
            view: {
                name: 'form'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'rqQuestionForm',
            view: {
                name: 'form'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'rqQuestionForm',
            view: ( modelElement, viewWriter ) => {
                const form = viewWriter.createContainerElement( 'form' );

                return toWidget( form, viewWriter );
            }
        } );

        // <questionFieldset> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'rqQuestionFieldset',
            view: {
                name: 'fieldset'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'rqQuestionFieldset',
            view: {
                name: 'fieldset'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'rqQuestionFieldset',
            view: ( modelElement, viewWriter ) => {
                const fieldset = viewWriter.createContainerElement( 'fieldset' );

                return toWidget( fieldset, viewWriter );
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
                // Note: You use a more specialized createEditableElement() method here.
                const div = viewWriter.createEditableElement( 'div', {} );


		const widgetContents = viewWriter.createUIElement(
			'select',
			null,
			function( domDocument ) {
				const domElement = this.toDomElement( domDocument );
				const correctness = modelElement.getAttribute( 'data-correctness' );
				domElement.innerHTML = `<select name="test">
    <option value="correct">Correct</option>
    <option value="incorrect">Incorrect</option>
    <option value="maybe">Maybe</option></select>`;
				return domElement;
			} );

		const insertPosition = viewWriter.createPositionAt( div, 0 );
		viewWriter.insert( insertPosition, widgetContents );




                return toWidgetEditable( div, viewWriter );
            }
        } );

        // <radio> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'radioInput',
            view: {
                name: 'input',
                type: 'radio'
            }

        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'radioInput',
            view: ( modelElement, viewWriter ) => {
                // Note: You use a more specialized createEditableElement() method here.
                const input = viewWriter.createEmptyElement( 'input', {'type': 'radio'} );
                return input;
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'radioInput',
            view: ( modelElement, viewWriter ) => {
                // Note: You use a more specialized createEditableElement() method here.
                const input = viewWriter.createEmptyElement( 'input', {'type': 'radio'} );
                return toWidget( input, viewWriter );
            }
        } );

        // <radio> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'radioLabel',
            view: {
                name: 'label'
            }

        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'radioLabel',
            view: {
                name: 'label'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'radioLabel',
            view: ( modelElement, viewWriter ) => {
                // Note: You use a more specialized createEditableElement() method here.
                const label = viewWriter.createEditableElement( 'label', {} );

                return toWidgetEditable( label, viewWriter );
            }
        } );

        // <answer> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'rqAnswer',
            view: {
                name: 'div',
                classes: 'rqAnswer'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'rqAnswer',
            view: {
                name: 'div',
                classes: 'rqAnswer'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'rqAnswer',
            view: ( modelElement, viewWriter ) => {
                const section = viewWriter.createContainerElement( 'div', { class: 'rqAnswer' } );

                return toWidget( section, viewWriter );
            }
        } );

        // <answerTitle> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'rqAnswerTitle',
            view: {
                name: 'h5'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'rqAnswerTitle',
            view: {
                name: 'h5'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'rqAnswerTitle',
            view: ( modelElement, viewWriter ) => {
                // Note: You use a more specialized createEditableElement() method here.
                const h5 = viewWriter.createEditableElement( 'h5', {} );

                return toWidgetEditable( h5, viewWriter );
            }
        } );

        // <answerText> converters
        conversion.for( 'upcast' ).elementToElement( {
            model: 'rqAnswerText',
            view: {
                name: 'div'
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'rqAnswerText',
            view: {
                name: 'div'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'rqAnswerText',
            view: ( modelElement, viewWriter ) => {
                // Note: You use a more specialized createEditableElement() method here.
                const div = viewWriter.createEditableElement( 'div', {} );

                return toWidgetEditable( div, viewWriter );
            }
        } );

    }
}
