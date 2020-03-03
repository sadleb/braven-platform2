import Plugin from '@ckeditor/ckeditor5-core/src/plugin';

const RETAINED_DATA_ATTRIBUTE = 'data-bz-retained';

/**
 * The retained data plugin. It is used by all plugins that must create new
 * retained data fields, e.g. ChecklistQuestionEditing.
 *
 * The basic concept is:
 *
 * - The plugin is initialized when the CKEditor component is loaded.
 * - It reads a `pageId` set in the global plugin config, and uses this to form a page-specific
 *   prefix for retained data ids. Any IDs not matching that prefix will be ignored.
 * - It listens to the view document for `change:attributes` events to look for new or changed
 *   retained data IDs. At initial page load, that means *all* IDs will be processed.
 * - It maintains an internal ID counter, which at page load is set to the highest previously used
 *   ID in the document, and is incremented every time `getNextId()` is called.
 *
 * Points to note:
 *
 * - Consecutively generated IDs are *NOT* guaranteed to use consecutive integers (and usually won't).
 * - Only the *FIRST* root in multi-root editors is supported. (This could be changed if we ever need
 *   to use a multi-root editor.)
 */
export default class RetainedData extends Plugin {
    static get pluginName() {
        return 'RetainedData';
    }

    init() {
        const editor = this.editor;
        const editingDoc = editor.editing.view.document;

        const pageId = editor.config.get( 'retainedData.pageId' );

        this._idCounter = 1;
        this._retainedDataPrefix = `retained_${pageId}_`;

        this._consumeAttributeEvent = this._consumeAttributeEvent.bind(this);
        this.getNextId = this.getNextId.bind(this);

        // Consume every attribute change event.
        editingDoc.listenTo( editingDoc.roots.first, 'change:attributes', this._consumeAttributeEvent );
    }

    getNextId() {
        return `${this._retainedDataPrefix}${this._idCounter++}`;
    }

    _consumeAttributeEvent( evt, elem ) {
        for ( let attribute of elem.getAttributeKeys() ) {

            // Ignore all but retained data IDs.
            if ( attribute === RETAINED_DATA_ATTRIBUTE ) {
                const value = elem.getAttribute( attribute );

                // Ignore all but retained data IDs that match our per-page prefix.
                if ( value.startsWith( this._retainedDataPrefix ) ) {
                    const idIntegerPart = parseInt( value.split( this._retainedDataPrefix ).pop() );

                    // If this ID is greater than our current counter, set the counter to this ID + 1.
                    // Otherwise, ignore it.
                    this._idCounter = Math.max( idIntegerPart + 1, this._idCounter );
                }

                // Once we hit the retained data attribute, exit early.
                break;
            }
        }
    }
}
