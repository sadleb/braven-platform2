import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { toWidget, toWidgetEditable } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';
import Table from '@ckeditor/ckeditor5-table/src/table';
import InsertMatrixQuestionCommand from './insertmatrixquestioncommand';

export default class MatrixQuestionEditing extends Plugin {
    static get requires() {
        return [ Widget, Table ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();

        this.editor.commands.add( 'insertMatrixQuestion', new InsertMatrixQuestionCommand( this.editor ) );
    }

    _defineSchema() {
        const schema = this.editor.model.schema;

        schema.register( 'matrixQuestion', {
            isObject: true,
            allowIn: 'section',
        } );

        schema.extend( 'table', {
            allowIn: 'questionFieldset',
        } );
    }

    _defineConverters() {
        const editor = this.editor;
        const conversion = editor.conversion;
        const { editing, data, model } = editor;

        // <matrixQuestion> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'div',
                classes: [ 'module-block', 'module-block-matrix' ]
            },
            model: ( viewElement, modelWriter ) => {
                return modelWriter.createElement( 'matrixQuestion' );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'matrixQuestion',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createEditableElement( 'div', {
                    'class': 'module-block module-block-matrix',
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'matrixQuestion',
            view: ( modelElement, viewWriter ) => {
                const matrixQuestion = viewWriter.createContainerElement( 'div', {
                    'class': 'module-block module-block-matrix',
                } );

                return toWidget( matrixQuestion, viewWriter, { label: 'matrix-question widget' } );
            }
        } );

    }
}
