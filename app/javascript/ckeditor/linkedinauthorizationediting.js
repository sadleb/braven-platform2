import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { toWidget, toWidgetEditable } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';
import InsertLinkedInAuthorizationCommand from './insertlinkedinauthorizationcommand';

export default class LinkedInAuthorizationEditing extends Plugin {
    static get requires() {
        return [ Widget ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();

        this.editor.commands.add(
            'insertLinkedInAuthorization',
            new InsertLinkedInAuthorizationCommand( this.editor ),
        );
    }

    _defineSchema() {
        const schema = this.editor.model.schema;

        schema.register( 'linkedInAuthorization', {
            isObject: true,
            allowIn: '$root',
            allowContentOf: [ '$root' ],
        });

        schema.register( 'iframe', {
            allowIn: 'linkedInAuthorization',
            allowAttributes: [ 'src' ],
        } );
    }

    _defineConverters() {
        const editor = this.editor;
        const conversion = editor.conversion;
        const { editing, data, model } = editor;

        // <linkedInAuthorization>
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'div',
                classes: 'linked-in-authorization',
            },
            model: 'linkedInAuthorization',
        });
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'linkedInAuthorization',
            view: {
                name: 'div',
                classes: 'linked-in-authorization',
            },
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'linkedInAuthorization',
            view: ( modelElement, { writer } ) => {
                const div = writer.createContainerElement( 'div', {
                    'class': 'linked-in-authorization',
                } );
                return toWidget( div, writer, { 
                    'hasSelectionHandle': true,
                    'label': 'LinkedIn authorization'
                } );
            }
        } );

        // <iframe>
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'iframe',
                classes: 'linked-in-authorization-button',
            },
            model: ( viewElement, { writer } ) => {
                return writer.createElement( 'iframe', {
                    'src': viewElement.getAttribute( 'src' ),
                } );
            }
        });
        conversion.for( 'downcast' ).elementToElement( {
            model: 'iframe',
            view: ( modelElement, { writer } ) => {
                return writer.createEmptyElement( 'iframe', {
                    'class': 'linked-in-authorization-button',
                    'src': modelElement.getAttribute('src'),
                } );
            },
        } );
    }
}
