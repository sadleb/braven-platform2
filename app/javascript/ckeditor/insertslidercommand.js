import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertSliderCommand extends Command {
    execute( id, options ) {
        this.editor.model.change( writer => {
            this.editor.model.insertContent( createSlider( writer, id, options ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'slider' );

        this.isEnabled = allowedIn !== null;
    }
}

function createSlider( writer, id, options ) {
    const sliderInput = writer.createElement( 'slider', options );
    return sliderInput;
}
