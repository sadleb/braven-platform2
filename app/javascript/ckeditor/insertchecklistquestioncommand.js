import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertChecklistQuestionCommand extends Command {
    execute( id ) {
        this.editor.model.change( writer => {
            const { checklistQuestion, selection } = createChecklistQuestion( writer, id );
            this.editor.model.insertContent( checklistQuestion );
            writer.setSelection( selection );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'checklistQuestion' );

        this.isEnabled = allowedIn !== null;
    }
}

function createChecklistQuestion( writer, id ) {
    const checklistQuestion = writer.createElement( 'checklistQuestion', {id} );
    const question = writer.createElement( 'question' );
    const questionTitle = writer.createElement( 'questionTitle' );
    const questionBody = writer.createElement( 'questionBody' );
    const questionForm = writer.createElement( 'questionForm' );
    const questionFieldset = writer.createElement( 'questionFieldset' );
    const doneButton = writer.createElement( 'doneButton', { 'data-bz-retained': id } );
    const checkboxDiv = writer.createElement( 'checkboxDiv' );
    const checkboxInput = writer.createElement( 'checkboxInput' );
    const checkboxLabel = writer.createElement( 'checkboxLabel' );
    const checkboxInlineFeedback = writer.createElement( 'checkboxInlineFeedback' );
    const answer = writer.createElement( 'answer' );
    const answerTitle = writer.createElement( 'answerTitle' );
    const answerText = writer.createElement( 'answerText' );

    const questionParagraph = writer.createElement( 'paragraph' );
    const answerParagraph = writer.createElement( 'paragraph' );

    writer.append( question, checklistQuestion );
    writer.append( questionTitle, question );
    writer.append( questionBody, question );
    writer.append( questionForm, question );
    writer.append( questionFieldset, questionForm );
    writer.append( doneButton, questionForm );
    writer.append( checkboxDiv, questionFieldset );
    writer.append( checkboxInput, checkboxDiv );
    writer.append( checkboxLabel, checkboxDiv );
    writer.append( checkboxInlineFeedback, checkboxDiv );
    writer.append( answer, checklistQuestion );
    writer.append( answerTitle, answer );
    writer.append( answerText, answer );
    // There must be at least one paragraph for the description to be editable.
    // See https://github.com/ckeditor/ckeditor5/issues/1464.
    writer.append( questionParagraph, questionBody );
    writer.append( answerParagraph, answerText );

    // Add text to empty editables where placeholders don't work.
    writer.insertText( 'Checkbox label', checkboxLabel );

    // Return the created element and desired selection position.
    const selection = writer.createPositionAt( questionTitle, 0 );

    return { checklistQuestion, selection };
}
