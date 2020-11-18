import Command from '@ckeditor/ckeditor5-core/src/command';
import UniqueId from './uniqueid';

const NUM_OPTIONS = 10;

export default class InsertNumericalSelectorCommand extends Command {
  execute( ) {
    this.editor.model.change( writer => {
      const inputName = this.editor.plugins.get('UniqueId').getNewName();
      const selector = createSelector( writer, inputName );
      this.editor.model.insertContent( selector );
      writer.setSelection( selector, 'on' );
    } );
  }

  refresh() {
    const model = this.editor.model;
    const selection = model.document.selection;
    const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'select' );

    this.isEnabled = allowedIn !== null;
  }
}

function createSelector( writer, inputName ) {
  const selector = writer.createElement( 'select', {
    'name': inputName,
    'data-bz-retained': inputName,
  } );

  const options = createOptions( writer );
  writer.append( options, selector );
  
  return selector;
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
