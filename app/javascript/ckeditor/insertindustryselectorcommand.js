import Command from '@ckeditor/ckeditor5-core/src/command';

// These retained data IDs come from the corresponding industry selectors in the "Design Your Career" project in Portal:
// https://portal.bebraven.org/courses/1/assignments/704
// We're using the same IDs so we can support existing Periscope dashboards.
const SELECTOR_RETAINED_DATA_IDS = [
  'dyc-industry-1',
  'dyc-industry-2',
];
const TEXTINPUT_RETAINED_DATA_ID = 'dyc-industry-freeform-other';

export default class InsertIndustrySelectorCommand extends Command {
  execute( ) {
    this.editor.model.change( writer => {
      const selector = createIndustrySelectorContainer( writer );
      this.editor.model.insertContent( selector );
      writer.setSelection( selector, 'on' );
    } );
  }

  refresh() {
    const model = this.editor.model;
    const selection = model.document.selection;
    const allowedIn = model.schema.findAllowedParent( selection.getFirstPosition(), 'industrySelectorContainer' );

    this.isEnabled = allowedIn !== null;
  }
}

function createIndustrySelectorContainer( writer ) {
  const container = writer.createElement( 'industrySelectorContainer' );

  const selector_prompt = 'Which two of these industries best fit your interests and goals:';
  const textarea_prompt = "If your industry of interest doesn't appear above, please enter it here:";

  writer.append( createParagraph( writer, selector_prompt ), container );
  writer.append( createSelector( writer, SELECTOR_RETAINED_DATA_IDS[0] ), container );
  writer.append( createParagraph( writer, 'and' ), container );
  writer.append( createSelector( writer, SELECTOR_RETAINED_DATA_IDS[1] ), container );
  writer.append( createParagraph( writer, textarea_prompt), container );
  writer.append( writer.createElement( 'textInput', { 'data-bz-retained': TEXTINPUT_RETAINED_DATA_ID } ), container );

  return container;
}

function createParagraph( writer, text ) {
  const paragraph = writer.createElement( 'paragraph' );
  writer.insertText( text, paragraph );
  return paragraph;
}

function createSelector( writer, retained_data_id ) {
  const selector = writer.createElement( 'select', { 'data-bz-retained': retained_data_id } );
  const options = createOptions( writer );

  writer.append( options, selector );
  
  return selector;
}

function createOptions( writer ) {
  const industries = [
    '',
    'Accounting',
    'Advertising',
    'Aerospace',
    'Banking',
    'Beauty / Cosmetics',
    'Biotechnology',
    'Business',
    'Chemical',
    'Communications',
    'Computer Engineering',
    'Computer Hardware',
    'Education',
    'Electronics',
    'Employment / Human Resources',
    'Energy',
    'Fashion',
    'Film',
    'Financial Services',
    'Fine Arts',
    'Food & Beverage',
    'Health',
    'Information Technology',
    'Insurance',
    'Journalism / News / Media',
    'Law',
    'Management / Strategic Consulting',
    'Manufacturing',
    'Medical Devices & Supplies',
    'Performing Arts',
    'Pharmaceutical',
    'Public Administration',
    'Public Relations',
    'Publishing',
    'Marketing',
    'Real Estate',
    'Sports',
    'Technology',
    'Telecommunications',
    'Tourism',
    'Transportation / Travel',
    'Writing',
  ];

  const selectOptions = industries.map( industry => {
    const option = writer.createElement( 'selectOption', { 'value': industry } );
    writer.insertText( industry , option );
    return option;
  });

  return selectOptions;
}
