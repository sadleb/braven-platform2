import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { toWidget } from '@ckeditor/ckeditor5-widget/src/utils';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';
import InsertContentPartPreviewCommand from './insertcontentpartpreviewcommand';

export default class ContentPartPreviewEditing extends Plugin {
    static get requires() {
        return [ Widget ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();

        this.editor.commands.add( 'insertContentPart', new InsertContentPartPreviewCommand( this.editor ) );
    }

    _defineSchema() {
        const schema = this.editor.model.schema;

        schema.register( 'contentPartPreview', {
            // Behaves like a self-contained object (e.g. an image).
            isObject: true,

            // Allow in places where other blocks are allowed (e.g. directly in the root).
            allowWhere: '$block',

            // Each content part preview has an ID. A unique ID tells the application which
            // content-part it represents and makes it possible to render it inside a widget.
            allowAttributes: [ 'id' ]
        } );
    }

    _defineConverters() {
        const editor = this.editor;
        const conversion = editor.conversion;
        const renderContentPart = editor.config.get( 'contentParts' ).contentPartRenderer;

        // <contentPartPreview> converters ((data) view → model)
        conversion.for( 'upcast' ).elementToElement( {
            view: {
                name: 'section',
                classes: 'content-part'
            },
            model: ( viewElement, modelWriter ) => {
                // Read the "data-id" attribute from the view and set it as the "id" in the model.
                return modelWriter.createElement( 'contentPartPreview', {
                    id: viewElement.getAttribute( 'data-id' )
                } );
            }
        } );

        // <contentPartPreview> converters (model → data view)
        conversion.for( 'dataDowncast' ).elementToElement( {
            model: 'contentPartPreview',
            view: ( modelElement, viewWriter ) => {
                // In the data view, the model <contentPartPreview> corresponds to:
                //
                // <section class="content-part" data-id="..."></section>
                return viewWriter.createEmptyElement( 'section', {
                    class: 'content-part',
                    'data-id': modelElement.getAttribute( 'id' )
                } );
            }
        } );

        // <contentPartPreview> converters (model → editing view)
        conversion.for( 'editingDowncast' ).elementToElement( {
            model: 'contentPartPreview',
            view: ( modelElement, viewWriter ) => {
                // In the editing view, the model <contentPartPreview> corresponds to:
                //
                // <section class="content-part" data-id="...">
                //     <div class="content-part__react-wrapper">
                //         <ContentPartPreview /> (React component)
                //     </div>
                // </section>
                const id = modelElement.getAttribute( 'id' );

                // The outermost <section class="content-part" data-id="..."></section> element.
                const section = viewWriter.createContainerElement( 'section', {
                    class: 'content-part',
                    'data-id': id
                } );

                // The inner <div class="content-part__react-wrapper"></div> element.
                // This element will host a React <ContentPartPreview /> component.
                const reactWrapper = viewWriter.createUIElement( 'div', {
                    class: 'content-part__react-wrapper'
                }, function( domDocument ) {
                    const domElement = this.toDomElement( domDocument );

                    // This the place where React renders the actual content-part preview hosted
                    // by a UIElement in the view. You are using a function (renderer) passed as
                    // editor.config.content-parts#contentPartRenderer.
                    renderContentPart( id, domElement );

                    return domElement;
                } );

                viewWriter.insert( viewWriter.createPositionAt( section, 0 ), reactWrapper );

                return toWidget( section, viewWriter, { label: 'content-part preview widget' } );
            }
        } );
    }
}
