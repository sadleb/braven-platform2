// See https://stackoverflow.com/questions/59040225/how-do-i-make-an-editable-label-for-an-input-within-a-ckeditor5-widget
// and https://github.com/ckeditor/ckeditor5-core/compare/proto/input-widget#diff-44ca1561ce575490eac0d660407d5144R239
export function preventCKEditorHandling( domElement, editor ) {
    // Prevent the editor from listening on below events in order to stop rendering selection.
    domElement.addEventListener( 'click', stopEventPropagationAndHackRendererFocus, { capture: true } );
    domElement.addEventListener( 'mousedown', stopEventPropagationAndHackRendererFocus, { capture: true } );
    domElement.addEventListener( 'focus', stopEventPropagationAndHackRendererFocus, { capture: true } );

    // Prevents TAB handling or other editor keys listeners which might be executed on editors selection.
    domElement.addEventListener( 'keydown', stopEventPropagationAndHackRendererFocus, { capture: true } );

    function stopEventPropagationAndHackRendererFocus( evt ) {
        evt.stopPropagation();
        // This prevents rendering changed view selection thus preventing to changing DOM selection while inside a widget.
        editor.editing.view._renderer.isFocused = false;
    }
}

// See https://github.com/ckeditor/ckeditor5/issues/1966#issuecomment-523794049
// and https://github.com/ckeditor/ckeditor5-core/blob/poc/customfigureattributes/tests/manual/customfigureattributes.js#L26
/**
 * Setups conversion for custom attribute on view elements contained inside figure.
 *
 * This method:
 *
 * - adds proper schema rules
 * - adds an upcast converter
 * - adds a downcast converter
 *
 * @param {String} viewElementName
 * @param {String} modelElementName
 * @param {String} viewAttribute
 * @param {module:core/editor/editor~Editor} editor
 */
export function setupCustomAttributeConversion( viewElementName, modelElementName, viewAttribute, editor ) {
    // Extend schema to store attribute in the model.
    const modelAttribute = `custom-${ viewAttribute }`;

    editor.model.schema.extend( modelElementName, { allowAttributes: [ modelAttribute ] } );

    editor.conversion.for( 'upcast' ).add( upcastAttribute( viewElementName, viewAttribute, modelAttribute ) );
    editor.conversion.for( 'downcast' ).add( downcastAttribute( modelElementName, viewElementName, viewAttribute, modelAttribute ) );
}
/**
 * Returns a custom attribute upcast converter.
 *
 * @param {String} viewElementName
 * @param {String} viewAttribute
 * @param {String} modelAttribute
 * @returns {Function}
 */
function upcastAttribute( viewElementName, viewAttribute, modelAttribute ) {
    return dispatcher => dispatcher.on( `element:${ viewElementName }`, ( evt, data, conversionApi ) => {
        const viewItem = data.viewItem;
        const modelRange = data.modelRange;

        const modelElement = modelRange && modelRange.start.nodeAfter;

        if ( !modelElement ) {
            return;
        }

        conversionApi.writer.setAttribute( modelAttribute, viewItem.getAttribute( viewAttribute ), modelElement );
    } );
}

/**
 * Returns a custom attribute downcast converter.
 *
 * @param {String} modelElementName
 * @param {String} viewElementName
 * @param {String} viewAttribute
 * @param {String} modelAttribute
 * @returns {Function}
 */
function downcastAttribute( modelElementName, viewElementName, viewAttribute, modelAttribute ) {
    return dispatcher => dispatcher.on( `attribute:${ modelAttribute }:${ modelElementName }`, ( evt, data, conversionApi ) => {
        const modelElement = data.item;

        const viewFigure = conversionApi.mapper.toViewElement( modelElement );
        const viewElement = findViewChild( viewFigure, viewElementName, conversionApi );

        if ( !viewElement ) {
            return;
        }

        if ( data.attributeNewValue === null ) {
            conversionApi.writer.removeAttribute( viewAttribute, viewElement );
        } else {
            conversionApi.writer.setAttribute( viewAttribute, data.attributeNewValue, viewElement );
        }

        conversionApi.writer.setAttribute( viewAttribute, modelElement.getAttribute( modelAttribute ), viewElement );
    } );
}

/**
 * Helper method that search for given view element in all children of model element.
 *
 * @param {module:engine/view/item~Item} viewElement
 * @param {String} viewElementName
 * @param {module:engine/conversion/downcastdispatcher~DowncastConversionApi} conversionApi
 * @return {module:engine/view/item~Item}
 */
function findViewChild( viewElement, viewElementName, conversionApi ) {
    const viewChildren = [ ...conversionApi.writer.createRangeIn( viewElement ).getItems() ];

    return viewChildren.find( item => item.is( viewElementName ) );
}

