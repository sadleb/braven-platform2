import Plugin from '@ckeditor/ckeditor5-core/src/plugin';

export default class AllowParagraphClass extends Plugin {
    static get requires() {
        return [ ];
    }

    init() {
        const editor = this.editor;

        // Allow the "paragraphClass" attribute in the editor model.
        editor.model.schema.extend( 'paragraph', { allowAttributes: [ 'paragraphClass', 'classb'] } );
     
        // Tell the editor that the model "paragraphClass" attribute converts into <p class="..."></p>
        editor.conversion.for( 'downcast' ).attributeToElement( {
            model: 'paragraphClass',
            view: ( attributeValue, writer ) => {
                const paragraphElement = writer.createAttributeElement( 'p', { 'classb': attributeValue }, { priority: 5 } );
                writer.setCustomProperty( 'paragraph', true, paragraphElement );
     
                console.log(paragraphElement);
                return paragraphElement;
            },
            converterPriority: 'low'
        } );
     
        // Tell the editor that <p class="..."></p> converts into the "paragraphClass" attribute in the model.
        editor.conversion.for( 'upcast' ).attributeToAttribute( {
            view: {
                name: 'p',
                key: 'classb'
            },
            model: 'paragraphClass',
            converterPriority: 'low'
        } );
    }
}
