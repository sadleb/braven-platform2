import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertChecklistQuestionCommand extends Command {
    execute( id ) {
        this.editor.model.change( writer => {
            // Insert <checklistQuestion id="...">*</checklistQuestion> at the current selection position
            // in a way which will result in creating a valid model structure.
            this.editor.model.insertContent( createChecklistQuestion( writer, id ) );
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
    const questionForm = writer.createElement( 'questionForm' );
    const questionFieldset = writer.createElement( 'questionFieldset' );
    const checkboxDiv = writer.createElement( 'checkboxDiv' );
    const checkboxInput = writer.createElement( 'checkboxInput' );
    const checkboxLabel = writer.createElement( 'checkboxLabel' );
    const answer = writer.createElement( 'answer' );
    const answerTitle = writer.createElement( 'answerTitle' );
    const answerText = writer.createElement( 'answerText' );
    const answerParagraph = writer.createElement( 'paragraph' );

    writer.append( question, checklistQuestion );
    writer.append( questionTitle, question );
    writer.append( questionForm, question );
    writer.append( questionFieldset, questionForm );
    writer.append( checkboxDiv, questionFieldset );
    writer.append( checkboxInput, checkboxDiv );
    writer.append( checkboxLabel, checkboxDiv );
    writer.append( answer, checklistQuestion );
    writer.append( answerTitle, answer );
    writer.append( answerText, answer );
    writer.append( answerParagraph, answerText );

    // Add text to empty editables, to get around the lack of placeholder support.
    // There must be at least one paragraph for the description to be editable.
    // See https://github.com/ckeditor/ckeditor5/issues/1464.
    writer.insertText( 'Question?', questionTitle );
    writer.insertText( 'Option 1', checkboxLabel );
    writer.insertText( 'Answer Title', answerTitle );
    writer.insertText( 'Answer body', answerParagraph );

    return checklistQuestion;
}
