import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { toWidget, toWidgetEditable } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';
import InsertMatchingQuestionCommand from './insertmatchingquestioncommand';
import InsertMatchingTableRow from './insertmatchingtablerowcommand';

export default class MatchingQuestionEditing extends Plugin {
    static get requires() {
        return [ Widget ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();

        this.editor.commands.add( 'insertMatchingQuestion', new InsertMatchingQuestionCommand( this.editor ) );
        this.editor.commands.add( 'insertMatchingTableRow', new InsertMatchingTableRow( this.editor ) );

        // Override the default 'enter' key behavior for checkbox labels.
        this.listenTo( this.editor.editing.view.document, 'enter', ( evt, data ) => {
            const positionParent = this.editor.model.document.selection.getLastPosition().parent;
            if ( positionParent.name == 'matchingTableCell' ) {
                this.editor.execute( 'insertMatchingTableRow' )
                data.preventDefault();
                evt.stop();
            }
        });
    }

    _defineSchema() {
        const schema = this.editor.model.schema;

        schema.register( 'matchingQuestion', {
            isObject: true,
            allowIn: 'section',
            allowAttributes: [ 'id', 'class' ]
        } );

        schema.register( 'matchingTable', {
            allowIn: 'question',
            allowAttributes: [ 'class' ],
        } );

        schema.register( 'matchingTableBody', {
            isLimit: true,
            allowIn: 'matchingTable'
        } );

        schema.register( 'matchingTableRow', {
            allowIn: 'matchingTableBody',
            allowAttributes: [ 'class' ]
        } );

        schema.register( 'matchingTableCell', {
            isInline: true,
            allowIn: 'matchingTableRow',
            allowContentOf: '$block',
            allowAttributes: [ 'class' ]
        } );
    }

    _defineConverters() {
        const editor = this.editor;
        const conversion = editor.conversion;
        const { editing, data, model } = editor;

        // <matchingQuestion> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'div',
                classes: ['module-block', 'module-block-matching']
            },
            model: ( viewElement, modelWriter ) => {
                // Read the "data-id" attribute from the view and set it as the "id" in the model.
                return modelWriter.createElement( 'matchingQuestion', {
                    id: parseInt( viewElement.getAttribute( 'data-id' ) )
                } );
            }
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'matchingQuestion',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createEditableElement( 'div', {
                    'class': 'module-block module-block-matching',
                    'data-id': modelElement.getAttribute( 'id' )
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'matchingQuestion',
            view: ( modelElement, viewWriter ) => {
                const id = modelElement.getAttribute( 'id' );

                const matchingQuestion = viewWriter.createContainerElement( 'div', {
                    'class': 'module-block module-block-matching',
                    'data-id': id
                } );

                return toWidget( matchingQuestion, viewWriter, { label: 'matching-question widget' } );
            }
        } );

        // <matchingTable> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'table',
                classes: ['sort-to-match', 'no-zebra']
            },
            model: 'matchingTable'
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'matchingTable',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createEditableElement( 'table', {
                    'class': 'sort-to-match no-zebra'
                } );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'matchingTable',
            view: ( modelElement, viewWriter ) => {
                const table = viewWriter.createEditableElement( 'table', {
                    'class': 'sort-to-match no-zebra'
                } );
                return toWidgetEditable( table, viewWriter );
            }
        } );

        // <matchingTableBody> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'tbody'
            },
            model: 'matchingTableBody'
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'matchingTableBody',
            view: {
                name: 'tbody'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'matchingTableBody',
            view: ( modelElement, viewWriter ) => {
                const body = viewWriter.createContainerElement( 'tbody' );
                return toWidget( body, viewWriter );
            }
        } );

        // <matchingTableRow> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'tr'
            },
            model: 'matchingTableRow'
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'matchingTableRow',
            //view: ( modelElement, viewWriter ) => {
            //    return viewWriter.createContainerElement( 'tr' );
            //}
            view: {
                name: 'tr'
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'matchingTableRow',
            view: ( modelElement, viewWriter ) => {
                const row = viewWriter.createContainerElement( 'tr' );
                return toWidget( row, viewWriter );
            }
        } );

        // <matchingTableCell> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'td'
            },
            model: 'matchingTableCell'
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'matchingTableCell',
            view: ( modelElement, viewWriter ) => {
                return viewWriter.createEditableElement( 'td' );
            }
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'matchingTableCell',
            view: ( modelElement, viewWriter ) => {
                const cell = viewWriter.createEditableElement( 'td' );
                return toWidgetEditable( cell, viewWriter );
            }
        } );
    }
}
