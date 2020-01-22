// From https://github.com/ckeditor/ckeditor5/issues/702#issuecomment-391730463
import Plugin from '@ckeditor/ckeditor5-core/src/plugin';

export default class ImageLink extends Plugin {

  init() {
    const editor = this.editor;
    editor.model.schema.extend( 'image', { allowAttributes: [ 'href' ] } );
    editor.conversion.for( 'upcast' ).add( upcastLink() );
    editor.conversion.for( 'upcast' ).add( upcastImageLink( 'img' ) );
    editor.conversion.for( 'upcast' ).add( upcastImageLink( 'figure' ) );
    editor.conversion.for( 'downcast' ).add( downcastImageLink() );
  }
}

/**
 * Returns converter for links that wraps <img> or <figure> elements.
 *
 * @returns {Function}
 */
function upcastLink() {
  return dispatcher => {
    dispatcher.on( 'element:a', ( evt, data, conversionApi ) => {
      const viewLink = data.viewItem;
      const imageInLink = Array.from( viewLink.getChildren() ).find( child => child.name === 'img' || child.name === 'figure' );

      if ( imageInLink ) {
        // There's an image (or figure) inside an <a> element - we consume it so it won't be picked up by Link plugin.
        const consumableAttributes = { attributes: [ 'href' ] };

        // Consume the link so the default one will not convert it to $text attribute.
        if ( !conversionApi.consumable.test( viewLink, consumableAttributes ) ) {
          // Might be consumed by something else - ie other converter with priority=highest - a standard check.
          return;
        }

        // Consume 'href' attribute from link element.
        conversionApi.consumable.consume( viewLink, consumableAttributes );
      }
    }, { priority: 'high' } );
  };
}

function upcastImageLink( elementName ) {
  return dispatcher => {
    dispatcher.on( `element:${ elementName }`, ( evt, data, conversionApi ) => {
      const viewImage = data.viewItem;
      const parent = viewImage.parent;

      // Check only <img>/<figure> that are direct children of a link.
      if ( parent.name === 'a' ) {
        const modelImage = Array.from( data.modelRange.getItems() ).find( item => item.is( 'image' ) );
        const linkHref = parent.getAttribute( 'href' );

        if ( modelImage && linkHref ) {
          // Set the href attribute from link element on model image element.
          conversionApi.writer.setAttribute( 'href', linkHref, modelImage );
        }
      }
    }, { priority: 'normal' } );
  };
}

function downcastImageLink() {
  return dispatcher => {
    dispatcher.on( 'attribute:href:image', ( evt, data, conversionApi ) => {
      const href = data.attributeNewValue;
      // The image will be already converted - so it will be present in the view.
      const viewImage = conversionApi.mapper.toViewElement( data.item );

      // Below will wrap already converted image by newly created link element.

      // 1. Create empty link element.
      const linkElement = conversionApi.writer.createContainerElement( 'a', { href } );

      // 2. Insert link before associated image.
      const positionBeforeImage = conversionApi.writer.createPositionBefore( viewImage );
      conversionApi.writer.insert( positionBeforeImage, linkElement );

      // 3. Move whole converted image to a link.
      const rangeOnImage = conversionApi.writer.createRangeOn( viewImage );
      const positionAtLink = conversionApi.writer.createPositionAt( linkElement, 0 );
      conversionApi.writer.move( rangeOnImage, positionAtLink );
    }, { priority: 'normal' } );
  };
}
