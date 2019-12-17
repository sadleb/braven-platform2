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
    const questionForm = writer.createElement( 'questionForm' );
    const questionFieldset = writer.createElement( 'questionFieldset' );
    const radioDiv = writer.createElement( 'radioDiv' );
    const radioInput = writer.createElement( 'radioInput' );
    const radioLabel = writer.createElement( 'radioLabel' );
    const answer = writer.createElement( 'answer' );
    const answerTitle = writer.createElement( 'answerTitle' );
    const answerText = writer.createElement( 'answerText' );
    const answerParagraph = writer.createElement( 'paragraph' );

    writer.append( question, radioQuestion );
    writer.append( questionTitle, question );
    writer.append( questionForm, question );
    writer.append( questionFieldset, questionForm );
    writer.append( radioDiv, questionFieldset );
    writer.append( radioInput, radioDiv );
    writer.append( radioLabel, radioDiv );
    writer.append( answer, radioQuestion );
    writer.append( answerTitle, answer );
    writer.append( answerText, answer );
    writer.append( answerParagraph, answerText );

    // Add text to empty editables, to get around the lack of placeholder support.
    // There must be at least one paragraph for the description to be editable.
    // See https://github.com/ckeditor/ckeditor5/issues/1464.
    writer.insertText( 'Question?', questionTitle );
    writer.insertText( 'Option 1', radioLabel );
    writer.insertText( 'Answer Title', answerTitle );
    writer.insertText( 'Answer body', answerParagraph );

    return radioQuestion;
}
