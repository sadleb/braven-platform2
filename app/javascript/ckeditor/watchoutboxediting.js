import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { toWidget, toWidgetEditable } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';
import InsertWatchOutBoxCommand from './insertwatchoutboxcommand';

export default class WatchOutBoxEditing extends Plugin {
    static get requires() {
        return [ Widget ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();
        this.editor.commands.add( 'insertWatchOutBox', new InsertWatchOutBoxCommand( this.editor ) );
    }

    _defineSchema() {
        const schema = this.editor.model.schema;

        schema.register( 'watchOutBoxContainer', {
            isObject: true,
            allowIn: '$root',
        } );

        schema.register( 'watchOutBox', {
            isLimit: true,
            allowIn: 'watchOutBoxContainer',
            allowContentOf: '$root'
        } );
    }

    _defineConverters() {
        const editor = this.editor;
        const conversion = editor.conversion;
        const { editing, data, model } = editor;

        // <watchOutBoxContainer> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'div',
                classes: 'watch-out-container',
            },
            model: 'watchOutBoxContainer',
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'watchOutBoxContainer',
            view: {
                name: 'div',
                classes: 'watch-out-container',
            },
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'watchOutBoxContainer',
            view: ( modelElement, { writer } ) => {
                const wrapper = writer.createContainerElement( 'div', {
                    'class': 'watch-out-container',
                } );

                return toWidget( wrapper, writer, { 'label': 'watch-out box container' } );
            },
        } );

        // <watchOutBox> converters
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'div',
                classes: 'watch-out',
            },
            model: 'watchOutBox',
        } );
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'watchOutBox',
            view: {
                name: 'div',
                classes: 'watch-out',
            },
        } );
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'watchOutBox',
            view: ( modelElement, { writer } ) => {
                const div =  writer.createEditableElement( 'div', {
                    'class': 'watch-out',
                } );
                return toWidgetEditable( div, writer, { 'label': 'watch-out box editable' } );
            },
        } );
    }
}
