import Command from '@ckeditor/ckeditor5-core/src/command';

export default class InsertFileUploadQuestionCommand extends Command {
    execute() {
        this.editor.model.change( writer => {
            this.editor.model.insertContent( createFileUploadQuestion( writer ) );
        } );
    }

    refresh() {
        const model = this.editor.model;
        const selection = model.document.selection;
        const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'moduleBlock' );

        this.isEnabled = allowedIn !== null;
    }
}

function createFileUploadQuestion( writer ) {
    const fileUploadQuestion = writer.createElement( 'moduleBlock' );
    const question = writer.createElement( 'question', { 'data-grade-as': 'fileupload' } );
    const questionTitle = writer.createElement( 'questionTitle' );
    const questionBody = writer.createElement( 'questionBody' );
    const questionForm = writer.createElement( 'questionForm' );
    const questionFieldset = writer.createElement( 'questionFieldset' );
    const doneButton = writer.createElement( 'doneButton' );
    const fileUpload = writer.createElement( 'fileUpload' );

    const questionParagraph = writer.createElement( 'paragraph' );

    writer.append( question, fileUploadQuestion );
    writer.append( questionTitle, question );
    writer.append( questionBody, question );
    writer.append( questionForm, question );
    writer.append( questionFieldset, questionForm );
    writer.append( doneButton, questionForm );
    writer.append( fileUpload, questionFieldset );

    // There must be at least one paragraph for the description to be editable.
    // See https://github.com/ckeditor/ckeditor5/issues/1464.
    writer.append( questionParagraph, questionBody );

    return fileUploadQuestion;
}
