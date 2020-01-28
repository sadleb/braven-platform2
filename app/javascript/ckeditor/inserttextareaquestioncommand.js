import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertTextAreaQuestionCommand extends Command {
    execute( id ) {
        this.editor.model.change( writer => {
            this.editor.model.insertContent( createTextAreaQuestion( writer, id ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'textAreaQuestion' );

        this.isEnabled = allowedIn !== null;
    }
}

function createTextAreaQuestion( writer, id ) {
    const textAreaQuestion = writer.createElement( 'textAreaQuestion', {id} );
    const question = writer.createElement( 'question' );
    const questionTitle = writer.createElement( 'questionTitle' );
    const questionBody = writer.createElement( 'questionBody' );
    const questionForm = writer.createElement( 'questionForm' );
    const questionFieldset = writer.createElement( 'questionFieldset' );
    const doneButton = writer.createElement( 'doneButton', { 'data-bz-retained': id } );
    const textArea = writer.createElement( 'textArea' );

    const questionParagraph = writer.createElement( 'paragraph' );

    writer.append( question, textAreaQuestion );
    writer.append( questionTitle, question );
    writer.append( questionBody, question );
    writer.append( questionForm, question );
    writer.append( questionFieldset, questionForm );
    writer.append( doneButton, questionForm );
    writer.append( textArea, questionFieldset );
    // There must be at least one paragraph for the description to be editable.
    // See https://github.com/ckeditor/ckeditor5/issues/1464.
    writer.append( questionParagraph, questionBody );

    return textAreaQuestion;
}
