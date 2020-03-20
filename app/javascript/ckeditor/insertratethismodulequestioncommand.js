import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertRateThisModuleQuestionCommand extends Command {
    execute() {
        this.editor.model.change( writer => {
            this.editor.model.insertContent( createRateThisModuleQuestion( writer ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'rateThisModuleQuestion' );

        this.isEnabled = allowedIn !== null;
    }
}

function createRateThisModuleQuestion( writer ) {
    const rateThisModuleQuestion = writer.createElement( 'rateThisModuleQuestion' );
    const question = writer.createElement( 'question', { 'data-grade-as': 'ratethismodule' } );
    const questionTitle = writer.createElement( 'questionTitle' );
    const questionForm = writer.createElement( 'questionForm' );
    const questionFieldset = writer.createElement( 'questionFieldset' );
    const sliderLegend = writer.createElement( 'legend' );
    const sliderContainer = writer.createElement( 'rateThisModuleSliderContainer' );
    const sliderLabelLeft = writer.createElement( 'rateThisModuleSliderLabelLeft' );
    const slider = writer.createElement( 'slider', {min: 0, max: 10} );
    const sliderLabelRight = writer.createElement( 'rateThisModuleSliderLabelRight' );
    const textAreaLegend = writer.createElement( 'legend' );
    const textArea = writer.createElement( 'textArea' );

    writer.append( question, rateThisModuleQuestion );
    writer.append( questionTitle, question );
    writer.append( questionForm, question );
    writer.append( questionFieldset, questionForm );
    writer.append( sliderLegend, questionFieldset );
    writer.append( sliderContainer, questionFieldset );
    writer.append( sliderLabelLeft, sliderContainer );
    writer.append( slider, sliderContainer );
    writer.append( sliderLabelRight, sliderContainer );
    writer.append( textAreaLegend, questionFieldset );
    writer.append( textArea, questionFieldset );

    // Hardcode all the text.
    writer.insertText( 'Rate This Module', questionTitle );
    writer.insertText( 'How useful was this module?', sliderLegend );
    writer.insertText( 'Not useful at all', sliderLabelLeft );
    writer.insertText( 'Very useful!', sliderLabelRight );
    writer.insertText( 'Do you have any other feedback on this module to share?', textAreaLegend );

    // Return the created element and desired selection position.
    return rateThisModuleQuestion;
}
