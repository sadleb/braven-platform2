import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import Heading from '@ckeditor/ckeditor5-heading/src/heading';
import AttributeEditing from './attributeediting';
import UniqueId from './uniqueid';
import { ELEMENT_ID_PREFIX } from './uniqueid';

export default class ElementIdEditing extends Plugin {
    static get requires() {
        return [ Heading, AttributeEditing, UniqueId ];
    }

    init() {
        this._getNewId = this.editor.plugins.get('UniqueId').getNewId;

        this._defineHeadingBehavior();
        this._attachListeners();
    }

    _defineHeadingBehavior() {
        const schema = this.editor.model.schema;
        const conversion = this.editor.conversion;

        // Support for setting/preserving heading IDs.
        // Note: The headings maps below must match the heading config defined in your config
        // for the CKEditor Heading plugin.
        const headings = [
            { model: 'heading1', view: 'h2' },
            { model: 'heading2', view: 'h3' },
            { model: 'heading3', view: 'h4' },
            { model: 'heading4', view: 'h5' },
            { model: 'heading5', view: 'h6' },
        ];

        headings.forEach( h => {
            // Schema.
            schema.extend( h.model, {
                allowAttributes: [ 'id' ],
            } );
            // Converters.
            conversion.attributeToAttribute( {
                model: { name: h.model, key: 'id' },
                view: { name: h.view, key: 'id' },
            } );
        } );
        // Schema.
        schema.setAttributeProperties( 'id', {
	        copyOnEnter: false
        } );
    }

    _attachListeners() {
        // Event handling.
        this.editor.model.on( 'applyOperation', ( eventInfo, args ) => {
            const operation = args[0];
            // When you choose "Paragraph" or a heading on the dropdown, it applies a RenameOperation.
            if ( operation.type == 'rename' ) {
                if ( operation.oldName == 'paragraph' && operation.newName.startsWith( 'heading' ) ) {
                    // paragraph -> heading; add an ID.
                    // Note: We have to add *an* ID here, but this ID is immediately replaced by the
                    // one generated in the addAttribute handling below. Unfortunately I can't think of
                    // a better way to do this.
                    const headingElement = operation.position.nodeAfter;
                    this.editor.execute( 'setAttributes', { 'id': this._getNewId() }, headingElement );
                } else if ( operation.oldName.startsWith( 'heading' ) && operation.newName == 'paragraph' ) {
                    // heading -> paragraph; remove ID if it exists.
                    const headingElement = operation.position.nodeAfter;
                    this.editor.execute( 'removeAttribute', 'id', headingElement );
                }
            // When you copy/paste an element that had an ID, it applies an AttributeOperation.
            // Note the operation.type for changing an *existing* attribute is changeAttribute, so this won't
            // end up catching its own events when it runs the setAttributes command.
            } else if ( operation.type == 'addAttribute' && operation.key == 'id' ) {
                // Only handle IDs we generated, just to make this a little less confusing.
                if ( operation.newValue.startsWith( ELEMENT_ID_PREFIX ) ) {
                    this.editor.execute( 'setAttributes', { 'id': this._getNewId() }, operation.range );
                }
            }
        } );
    }
}
