import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import Widget from '@ckeditor/ckeditor5-widget/src/widget';

import AddTooltipCommand from './addtooltipcommand';
import RemoveTooltipCommand from './removetooltipcommand';


export default class TooltipEditing extends Plugin {
    static get requires() {
        return [ ];
    }

    init() {
        this._defineSchema();
        this._defineConverters();
    }

    _defineSchema() {
        const schema = this.editor.model.schema;

        schema.extend( '$text', { allowAttributes: 'tooltipText' } );
    }

    _defineConverters() {
        const editor = this.editor;
        const conversion = editor.conversion;

        conversion.for( 'dataDowncast' )
            .attributeToElement( { model: 'tooltipText', view: createTooltipElement } );

        conversion.for( 'editingDowncast' )
            .attributeToElement( { model: 'tooltipText', view: ( title, writer ) => {
                return createTooltipElement( title, writer );
            } } );

        // We have to use a lower-level dispatcher because otherwise this conflicts with the span upcast in
        // customelementattributepreservation.js and we end up with double spans.
        // MUST use 'lowest' priority, to avoid converting before parent nodes exist.
        // See https://github.com/ckeditor/ckeditor5/issues/4529.
        // Not sure why 'low' specified in the docs doesn't work.
        conversion.for( 'upcast' )
            .add( dispatcher => { dispatcher.on( 'element:span', ( evt, data, conversionApi ) => {
                if ( conversionApi.consumable.consume( data.viewItem, { name: true, classes: [ 'has-tooltip' ], attributes: [ 'title' ] } ) ) {
                    // <span> element is inline and is represented by an attribute in the model.
                    // This is why we need to convert only children.
                    const { modelRange } = conversionApi.convertChildren( data.viewItem, data.modelCursor );

                    for ( let item of modelRange.getItems() ) {
                        if ( conversionApi.schema.checkAttribute( item, 'tooltipText' ) ) {
                            conversionApi.writer.setAttribute( 'tooltipText', data.viewItem.getAttribute( 'title' ), item );
                        }
                    }
                }
            }, { priority: 'lowest' } );
        } );

        editor.commands.add( 'addTooltip', new AddTooltipCommand( editor ) );
        editor.commands.add( 'removeTooltip', new RemoveTooltipCommand( editor ) );
    }
}

function createTooltipElement( title, writer ) {
    // Priority 5 - https://github.com/ckeditor/ckeditor5-link/issues/121.
    const tooltipElement = writer.createAttributeElement( 'span', { 'title': title, 'class': 'has-tooltip' }, { priority: 5 } );
    writer.setCustomProperty( 'tooltip', true, tooltipElement );

    return tooltipElement;
}
