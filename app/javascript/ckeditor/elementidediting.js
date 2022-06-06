// Custom element/attribute management.
// This file works together with clipboardattributeediting.js.

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
        this._getNewId = this.editor.plugins.get( 'UniqueId' ).getNewId;

        this._defineHeadingBehavior();
        this._attachListeners();
    }

    _defineHeadingBehavior() {
        const model = this.editor.model;
        const schema = model.schema;
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
        // PostFixer.
        model.document.registerPostFixer( writer => this._elementPostFixer( writer, model ) );
    }

    _attachListeners() {
        // Event handling.
        this.editor.model.document.on( 'change', ( eventInfo, batch ) => {
            for ( const operation of batch.operations ) {
                // When you choose "Paragraph" or a heading on the dropdown, it applies a RenameOperation.
                if ( operation.type === 'rename' ) {
                    if ( operation.oldName.startsWith( 'heading' ) && !operation.newName.startsWith( 'heading' ) ) {
                        // heading -> something else; remove ID if it exists.
                        // We don't have to handle this for things other than
                        // headings, because we only add IDs to headings and
                        // inputs (which can't be transformed via rename).
                        const newElement = operation.position.nodeAfter;
                        this.editor.model.change( writer => {
                            writer.removeAttribute( 'id', newElement );
                        } );
                    }
                }
            }
        } );
    }

    _elementPostFixer( writer, model ) {
        const changes = model.document.differ.getChanges();

        for ( const entry of changes ) {
            if ( entry.type === 'insert' ) {
                // Ignore everything but headings.
                // Because this is an insert change type, the inserted elements
                // we care about will be headings. We handle heading->other
                // things in the change event listener above.
                if ( !entry.name.startsWith( 'heading' ) ) {
                    return false;
                }

                // Note: CKE5 v34.0.0 introduced entry.attributes which we might
                // be able to use here; but we're on v26.0.0, so until we
                // upgrade, we have to use this workaround to determine related
                // elements/attributes.
                const nodeBefore = entry.position.nodeBefore;
                const nodeAfter = entry.position.nodeAfter;

                if ( nodeAfter && nodeAfter.name.startsWith( 'heading' ) ) {
                    if ( nodeAfter.getAttribute( 'id' ) === undefined ) {
                        // We just created a new heading. Set its ID.
                        writer.setAttribute( 'id', this._getNewId(), nodeAfter );
                        return true;
                    } else if ( nodeBefore && nodeBefore.name.startsWith( 'heading' ) &&
                            nodeBefore.getAttribute( 'id' ) === nodeAfter.getAttribute( 'id' ) ) {
                        // We just "split" a heading, creating two headings
                        // with the same ID. This only happens when the cursor
                        // is at the beginning or in the middle of a heading,
                        // and the user presses Enter.
                        if ( nodeBefore.childCount === 0 ) {
                            // If the cursor was at the beginning of the
                            // heading, the desired behavior when pressing
                            // Enter is to create a new paragraph above the
                            // heading.
                            writer.removeAttribute( 'id', nodeBefore );
                            writer.rename( nodeBefore, 'paragraph' );
                            return true;
                        } else {
                            // If the cursor was in the middle of the heading,
                            // the desired behavior is to create two headings.
                            // We can't know which one the user intended to
                            // keep the ID, so we arbitrarily pick the top one.
                            writer.setAttribute( 'id', this._getNewId(), nodeAfter );
                            return true;
                        }
                    }
                }
            }
        }
    }
}
