import Command from '@ckeditor/ckeditor5-core/src/command';
import UniqueId from './uniqueid';

const NUM_OPTIONS = 10;

export default class InsertNumericalSelectorCommand extends Command {
  execute( ) {
    this.editor.model.change( writer => {
      const uniqueId = new UniqueId();
      const inputName = uniqueId.getNewName();
      const inputId = uniqueId.getNewId();
      const selector = createSelector( writer, inputName, inputId );
      this.editor.model.insertContent( selector );
      writer.setSelection( selector, 'on' );
    } );
  }

  refresh() {
    const model = this.editor.model;
    const selection = model.document.selection;
    const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'selectWrapper' );

    this.isEnabled = allowedIn !== null;
  }
}

function createSelector( writer, inputName, inputId ) {
  const selectWrapper = writer.createElement( 'selectWrapper' );

  const selectLabel = writer.createElement( 'selectLabel' );
  writer.insertText( 'Choose a number:', selectLabel );

  const selector = writer.createElement( 'select', {
    'name': inputName,
    'id': inputId,
  } );

  const options = createOptions( writer );

  writer.append( selectLabel, selectWrapper );
  writer.append( selector, selectWrapper );
  writer.append( options, selector );
  
  return selectWrapper;
}

function createOptions( writer ) {
  // Create list of options beginning with empty '' and then values [1, NUM_OPTIONS]
  const values = [''].concat([...Array(NUM_OPTIONS + 1).keys()].slice(1));

  const selectOptions = values.map( value => {
    const option = writer.createElement( 'selectOption', { 'value': value.toString() } );
    writer.insertText( value.toString(), option );
    return option;
  });

  return selectOptions;
}
