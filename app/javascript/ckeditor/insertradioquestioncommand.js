import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertRadioQuestionCommand extends Command {
    execute( id ) {
        this.editor.model.change( writer => {
            // Insert <radioQuestion id="...">*</radioQuestion> at the current selection position
            // in a way which will result in creating a valid model structure.
            this.editor.model.insertContent( createRadioQuestion( writer, id ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'radioQuestion' );

        this.isEnabled = allowedIn !== null;
    }
}

function createRadioQuestion( writer, id ) {
    const radioQuestion = writer.createElement( 'radioQuestion', {id} );
    const question = writer.createElement( 'question' );
    const questionTitle = writer.createElement( 'questionTitle' );
    const questionBody = writer.createElement( 'questionBody' );
    const questionForm = writer.createElement( 'questionForm' );
    const questionFieldset = writer.createElement( 'questionFieldset' );
    const radioDiv = writer.createElement( 'radioDiv' );
    const radioInput = writer.createElement( 'radioInput' );
    const radioLabel = writer.createElement( 'radioLabel' );
    const radioInlineFeedback = writer.createElement( 'radioInlineFeedback' );
    const answer = writer.createElement( 'answer' );
    const answerTitle = writer.createElement( 'answerTitle' );
    const answerText = writer.createElement( 'answerText' );

    const questionParagraph = writer.createElement( 'paragraph' );
    const answerParagraph = writer.createElement( 'paragraph' );

    writer.append( question, radioQuestion );
    writer.append( questionTitle, question );
    writer.append( questionBody, question );
    writer.append( questionForm, question );
    writer.append( questionFieldset, questionForm );
    writer.append( radioDiv, questionFieldset );
    writer.append( radioInput, radioDiv );
    writer.append( radioLabel, radioDiv );
    writer.append( radioInlineFeedback, radioDiv );
    writer.append( answer, radioQuestion );
    writer.append( answerTitle, answer );
    writer.append( answerText, answer );
    // There must be at least one paragraph for the description to be editable.
    // See https://github.com/ckeditor/ckeditor5/issues/1464.
    writer.append( questionParagraph, questionBody );
    writer.append( answerParagraph, answerText );

    // Add text to empty editables where placeholders don't work.
    writer.insertText( 'Radio label', radioLabel );

    return radioQuestion;
}