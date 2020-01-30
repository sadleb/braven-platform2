import Plugin from '@ckeditor/ckeditor5-core/src/plugin';

const RETAINED_DATA_ATTRIBUTE = 'data-bz-retained';

export default class RetainedData extends Plugin {
    static get pluginName() {
        return 'RetainedData';
    }

    init() {
        const editor = this.editor;
        const editingDoc = editor.editing.view.document;

        const pageId = editor.config.get( 'retainedData.pageId' );

        this._idCounter = 1;
        this._retainedDataPrefix = `retained_${pageId}_`

        this._consumeAttributeEvent = this._consumeAttributeEvent.bind(this);
        this.getNextId = this.getNextId.bind(this);

        editingDoc.listenTo( editingDoc.roots.first, 'change:attributes', this._consumeAttributeEvent );
    }

    getNextId() {
        return `${this._retainedDataPrefix}${this._idCounter++}`;
    }

    _consumeAttributeEvent( evt, elem ) {
        for ( let attribute of elem.getAttributeKeys() ) {

            if ( attribute === RETAINED_DATA_ATTRIBUTE ) {
                const value = elem.getAttribute( attribute );

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
