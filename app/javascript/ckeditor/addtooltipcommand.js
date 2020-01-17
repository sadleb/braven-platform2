/**
 * @license Copyright (c) 2003-2020, CKSource - Frederico Knabben. All rights reserved.
 * For licensing, see LICENSE.md or https://ckeditor.com/legal/ckeditor-oss-license
 */

/**
 * @module tooltip/addtooltipcommand
 */

import Command from '@ckeditor/ckeditor5-core/src/command';
import findTooltipRange from './findtooltiprange';
import toMap from '@ckeditor/ckeditor5-utils/src/tomap';
import Collection from '@ckeditor/ckeditor5-utils/src/collection';

/**
 * The tooltip command. It is used by the {@tooltip module:tooltip/tooltip~Tooltip tooltip feature}.
 *
 * @extends module:core/command~Command
 */
export default class AddTooltipCommand extends Command {
	/**
	 * The value of the `'tooltipText'` attribute if the start of the selection is located in a node with this attribute.
	 *
	 * @observable
	 * @readonly
	 * @member {Object|undefined} #value
	 */

	constructor( editor ) {
		super( editor );

		/**
		 * A collection of {@tooltip module:tooltip/utils~ManualDecorator manual decorators}
		 * corresponding to the {@tooltip module:tooltip/tooltip~TooltipConfig#decorators decorator configuration}.
		 *
		 * You can consider it a model with states of manual decorators added to the currently selected tooltip.
		 *
		 * @readonly
		 * @type {module:utils/collection~Collection}
		 */
		this.manualDecorators = new Collection();
	}

	/**
	 * Synchronizes the state of {@tooltip #manualDecorators} with the currently present elements in the model.
	 */
	restoreManualDecoratorStates() {
		for ( const manualDecorator of this.manualDecorators ) {
			manualDecorator.value = this._getDecoratorStateFromModel( manualDecorator.id );
		}
	}

	/**
	 * @inheritDoc
	 */
	refresh() {
		const model = this.editor.model;
		const doc = model.document;

		this.value = doc.selection.getAttribute( 'tooltipText' );

		for ( const manualDecorator of this.manualDecorators ) {
			manualDecorator.value = this._getDecoratorStateFromModel( manualDecorator.id );
		}

		this.isEnabled = model.schema.checkAttributeInSelection( doc.selection, 'tooltipText' );
	}

	/**
	 * Executes the command.
	 *
	 * When the selection is non-collapsed, the `tooltipText` attribute will be applied to nodes inside the selection, but only to
	 * those nodes where the `tooltipText` attribute is allowed (disallowed nodes will be omitted).
	 *
	 * When the selection is collapsed and is not inside the text with the `tooltipText` attribute, a
	 * new {@tooltip module:engine/model/text~Text text node} with the `tooltipText` attribute will be inserted in place of the caret, but
	 * only if such element is allowed in this place. The `_data` of the inserted text will equal the `title` parameter.
	 * The selection will be updated to wrap the just inserted text node.
	 *
	 * When the selection is collapsed and inside the text with the `tooltipText` attribute, the attribute value will be updated.
	 *
	 * # Decorators and model attribute management
	 *
	 * There is an optional argument to this command that applies or removes model
	 * {@gtooltip framework/guides/architecture/editing-engine#text-attributes text attributes} brought by
	 * {@tooltip module:tooltip/utils~ManualDecorator manual tooltip decorators}.
	 *
	 * Text attribute names in the model correspond to the entries in the {@tooltip module:tooltip/tooltip~TooltipConfig#decorators configuration}.
	 * For every decorator configured, a model text attribute exists with the "tooltip" prefix. For example, a `'tooltipMyDecorator'` attribute
	 * corresponds to `'myDecorator'` in the configuration.
	 *
	 * To learn more about tooltip decorators, check out the {@tooltip module:tooltip/tooltip~TooltipConfig#decorators `config.tooltip.decorators`}
	 * documentation.
	 *
	 * Here is how to manage decorator attributes with the tooltip command:
	 *
	 *		const addTooltipCommand = editor.commands.get( 'addTooltip' );
	 *
	 *		// Adding a new decorator attribute.
	 *		addTooltipCommand.execute( 'http://example.com', {
	 *			tooltipIsExternal: true
	 *		} );
	 *
	 *		// Removing a decorator attribute from the selection.
	 *		addTooltipCommand.execute( 'http://example.com', {
	 *			tooltipIsExternal: false
	 *		} );
	 *
	 *		// Adding multiple decorator attributes at the same time.
	 *		addTooltipCommand.execute( 'http://example.com', {
	 *			tooltipIsExternal: true,
	 *			tooltipIsDownloadable: true,
	 *		} );
	 *
	 *		// Removing and adding decorator attributes at the same time.
	 *		addTooltipCommand.execute( 'http://example.com', {
	 *			tooltipIsExternal: false,
	 *			tooltipFoo: true,
	 *			tooltipIsDownloadable: false,
	 *		} );
	 *
	 * **Note**: If the decorator attribute name is not specified, its state remains untouched.
	 *
	 * **Note**: {@tooltip module:tooltip/removetooltipcommand~RemoveTooltipCommand#execute `RemoveTooltipCommand#execute()`} removes all
	 * decorator attributes.
	 *
	 * @fires execute
	 * @param {String} title Tooltip destination.
	 * @param {Object} [manualDecoratorIds={}] The information about manual decorator attributes to be applied or removed upon execution.
	 */
	execute( title, manualDecoratorIds = {} ) {
		const model = this.editor.model;
		const selection = model.document.selection;
		// Stores information about manual decorators to turn them on/off when command is applied.
		const truthyManualDecorators = [];
		const falsyManualDecorators = [];

		for ( const name in manualDecoratorIds ) {
			if ( manualDecoratorIds[ name ] ) {
				truthyManualDecorators.push( name );
			} else {
				falsyManualDecorators.push( name );
			}
		}

		model.change( writer => {
			// If selection is collapsed then update selected tooltip or insert new one at the place of caret.
			if ( selection.isCollapsed ) {
				const position = selection.getFirstPosition();

				// When selection is inside text with `tooltipText` attribute.
				if ( selection.hasAttribute( 'tooltipText' ) ) {
					// Then update `tooltipText` value.
					const tooltipRange = findTooltipRange( position, selection.getAttribute( 'tooltipText' ), model );

					writer.setAttribute( 'tooltipText', title, tooltipRange );

					truthyManualDecorators.forEach( item => {
						writer.setAttribute( item, true, tooltipRange );
					} );

					falsyManualDecorators.forEach( item => {
						writer.removeAttribute( item, tooltipRange );
					} );

					// Create new range wrapping changed tooltip.
					writer.setSelection( tooltipRange );
				}
				// If not then insert text node with `tooltipText` attribute in place of caret.
				// However, since selection in collapsed, attribute value will be used as data for text node.
				// So, if `title` is empty, do not create text node.
				else if ( title !== '' ) {
					const attributes = toMap( selection.getAttributes() );

					attributes.set( 'tooltipText', title );

					truthyManualDecorators.forEach( item => {
						attributes.set( item, true );
					} );

					const node = writer.createText( title, attributes );

					model.insertContent( node, position );

					// Create new range wrapping created node.
					writer.setSelection( writer.createRangeOn( node ) );
				}
			} else {
				// If selection has non-collapsed ranges, we change attribute on nodes inside those ranges
				// omitting nodes where `tooltipText` attribute is disallowed.
				const ranges = model.schema.getValidRanges( selection.getRanges(), 'tooltipText' );

				for ( const range of ranges ) {
					writer.setAttribute( 'tooltipText', title, range );

					truthyManualDecorators.forEach( item => {
						writer.setAttribute( item, true, range );
					} );

					falsyManualDecorators.forEach( item => {
						writer.removeAttribute( item, range );
					} );
				}
			}
		} );
	}

	/**
	 * Provides information whether a decorator with a given name is present in the currently processed selection.
	 *
	 * @private
	 * @param {String} decoratorName The name of the manual decorator used in the model
	 * @returns {Boolean} The information whether a given decorator is currently present in the selection.
	 */
	_getDecoratorStateFromModel( decoratorName ) {
		const doc = this.editor.model.document;
		return doc.selection.getAttribute( decoratorName ) || false;
	}
}
