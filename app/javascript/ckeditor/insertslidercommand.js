import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertSliderCommand extends Command {
    execute( id ) {
        this.editor.model.change( writer => {
            this.editor.model.insertContent( createSlider( writer, id ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'slider' );

        this.isEnabled = allowedIn !== null;
    }
}

function createSlider( writer, id ) {
    const sliderInput = writer.createElement( 'slider' );
    return sliderInput;
}
