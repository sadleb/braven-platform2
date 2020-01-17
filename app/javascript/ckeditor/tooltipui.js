/**
 * @license Copyright (c) 2003-2020, CKSource - Frederico Knabben. All rights reserved.
 * For licensing, see LICENSE.md or https://ckeditor.com/legal/ckeditor-oss-license
 */

/**
 * @module tooltip/tooltipui
 */

import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import ClickObserver from '@ckeditor/ckeditor5-engine/src/view/observer/clickobserver';
import ContextualBalloon from '@ckeditor/ckeditor5-ui/src/panel/balloon/contextualballoon';

import clickOutsideHandler from '@ckeditor/ckeditor5-ui/src/bindings/clickoutsidehandler';

import ButtonView from '@ckeditor/ckeditor5-ui/src/button/buttonview';
import TooltipFormView from './ui/tooltipformview';
import TooltipActionsView from './ui/tooltipactionsview';

import tooltipIcon from './theme/icons/tooltip.svg';

/**
 * The tooltip UI plugin. It introduces the `'addTooltip'` and `'removeTooltip'` buttons and support for the <kbd>Ctrl+K</kbd> keystroke.
 *
 * It uses the
 * {@tooltip module:ui/panel/balloon/contextualballoon~ContextualBalloon contextual balloon plugin}.
 *
 * @extends module:core/plugin~Plugin
 */
export default class TooltipUI extends Plugin {
	/**
	 * @inheritDoc
	 */
	static get requires() {
		return [ ContextualBalloon ];
	}

	/**
	 * @inheritDoc
	 */
	static get pluginName() {
		return 'TooltipUI';
	}

	/**
	 * @inheritDoc
	 */
	init() {
		const editor = this.editor;

		editor.editing.view.addObserver( ClickObserver );

		/**
		 * The actions view displayed inside of the balloon.
		 *
		 * @member {module:tooltip/ui/tooltipactionsview~TooltipActionsView}
		 */
		this.actionsView = this._createActionsView();

		/**
		 * The form view displayed inside the balloon.
		 *
		 * @member {module:tooltip/ui/tooltipformview~TooltipFormView}
		 */
		this.formView = this._createFormView();

		/**
		 * The contextual balloon plugin instance.
		 *
		 * @private
		 * @member {module:ui/panel/balloon/contextualballoon~ContextualBalloon}
		 */
		this._balloon = editor.plugins.get( ContextualBalloon );

		// Create toolbar buttons.
		this._createToolbarTooltipButton();

		// Attach lifecycle actions to the the balloon.
		this._enableUserBalloonInteractions();
	}

	/**
	 * @inheritDoc
	 */
	destroy() {
		super.destroy();

		// Destroy created UI components as they are not automatically destroyed (see ckeditor5#1341).
		this.formView.destroy();
	}

	/**
	 * Creates the {@tooltip module:tooltip/ui/tooltipactionsview~TooltipActionsView} instance.
	 *
	 * @private
	 * @returns {module:tooltip/ui/tooltipactionsview~TooltipActionsView} The tooltip actions view instance.
	 */
	_createActionsView() {
		const editor = this.editor;
		const actionsView = new TooltipActionsView( editor.locale );
		const tooltipCommand = editor.commands.get( 'addTooltip' );
		const removeTooltipCommand = editor.commands.get( 'removeTooltip' );

		actionsView.bind( 'title' ).to( tooltipCommand, 'value' );
		actionsView.editButtonView.bind( 'isEnabled' ).to( tooltipCommand );
		actionsView.removeTooltipButtonView.bind( 'isEnabled' ).to( removeTooltipCommand );

		// Execute removeTooltip command after clicking on the "Edit" button.
		this.listenTo( actionsView, 'edit', () => {
			this._addFormView();
		} );

		// Execute removeTooltip command after clicking on the "Untooltip" button.
		this.listenTo( actionsView, 'removeTooltip', () => {
			editor.execute( 'removeTooltip' );
			this._hideUI();
		} );

		// Close the panel on esc key press when the **actions have focus**.
		actionsView.keystrokes.set( 'Esc', ( data, cancel ) => {
			this._hideUI();
			cancel();
		} );

		return actionsView;
	}

	/**
	 * Creates the {@tooltip module:tooltip/ui/tooltipformview~TooltipFormView} instance.
	 *
	 * @private
	 * @returns {module:tooltip/ui/tooltipformview~TooltipFormView} The tooltip form view instance.
	 */
	_createFormView() {
		const editor = this.editor;
		const tooltipCommand = editor.commands.get( 'addTooltip' );

		const formView = new TooltipFormView( editor.locale, tooltipCommand.manualDecorators );

		formView.urlInputView.bind( 'value' ).to( tooltipCommand, 'value' );

		// Form elements should be read-only when corresponding commands are disabled.
		formView.urlInputView.bind( 'isReadOnly' ).to( tooltipCommand, 'isEnabled', value => !value );
		formView.saveButtonView.bind( 'isEnabled' ).to( tooltipCommand );

		// Execute tooltip command after clicking the "Save" button.
		this.listenTo( formView, 'submit', () => {
			editor.execute( 'addTooltip', formView.urlInputView.inputView.element.value, formView.getDecoratorSwitchesState() );
			this._closeFormView();
		} );

		// Hide the panel after clicking the "Cancel" button.
		this.listenTo( formView, 'cancel', () => {
			this._closeFormView();
		} );

		// Close the panel on esc key press when the **form has focus**.
		formView.keystrokes.set( 'Esc', ( data, cancel ) => {
			this._closeFormView();
			cancel();
		} );

		return formView;
	}

	/**
	 * Creates a toolbar Tooltip button. Clicking this button will show
	 * a {@tooltip #_balloon} attached to the selection.
	 *
	 * @private
	 */
	_createToolbarTooltipButton() {
		const editor = this.editor;
		const tooltipCommand = editor.commands.get( 'addTooltip' );
		const t = editor.t;

		editor.ui.componentFactory.add( 'addTooltip', locale => {
			const button = new ButtonView( locale );

			button.isEnabled = true;
			button.label = t( 'Tooltip' );
			//button.icon = tooltipIcon;
			button.tooltip = true;
			button.isToggleable = true;

			// Bind button to the command.
			button.bind( 'isEnabled' ).to( tooltipCommand, 'isEnabled' );
			button.bind( 'isOn' ).to( tooltipCommand, 'value', value => !!value );

			// Show the panel on button click.
			this.listenTo( button, 'execute', () => this._showUI( true ) );

			return button;
		} );
	}

	/**
	 * Attaches actions that control whether the balloon panel containing the
	 * {@tooltip #formView} is visible or not.
	 *
	 * @private
	 */
	_enableUserBalloonInteractions() {
		const viewDocument = this.editor.editing.view.document;

		// Handle click on view document and show panel when selection is placed inside the tooltip element.
		// Keep panel open until selection will be inside the same tooltip element.
		this.listenTo( viewDocument, 'click', () => {
			const parentTooltip = this._getSelectedTooltipElement();

			if ( parentTooltip ) {
				// Then show panel but keep focus inside editor editable.
				this._showUI();
			}
		} );

		// Focus the form if the balloon is visible and the Tab key has been pressed.
		this.editor.keystrokes.set( 'Tab', ( data, cancel ) => {
			if ( this._areActionsVisible && !this.actionsView.focusTracker.isFocused ) {
				this.actionsView.focus();
				cancel();
			}
		}, {
			// Use the high priority because the tooltip UI navigation is more important
			// than other feature's actions, e.g. list indentation.
			// https://github.com/ckeditor/ckeditor5-tooltip/issues/146
			priority: 'high'
		} );

		// Close the panel on the Esc key press when the editable has focus and the balloon is visible.
		this.editor.keystrokes.set( 'Esc', ( data, cancel ) => {
			if ( this._isUIVisible ) {
				this._hideUI();
				cancel();
			}
		} );

		// Close on click outside of balloon panel element.
		clickOutsideHandler( {
			emitter: this.formView,
			activator: () => this._isUIInPanel,
			contextElements: [ this._balloon.view.element ],
			callback: () => this._hideUI()
		} );
	}

	/**
	 * Adds the {@tooltip #actionsView} to the {@tooltip #_balloon}.
	 *
	 * @protected
	 */
	_addActionsView() {
		if ( this._areActionsInPanel ) {
			return;
		}

		this._balloon.add( {
			view: this.actionsView,
			position: this._getBalloonPositionData()
		} );
	}

	/**
	 * Adds the {@tooltip #formView} to the {@tooltip #_balloon}.
	 *
	 * @protected
	 */
	_addFormView() {
		if ( this._isFormInPanel ) {
			return;
		}

		const editor = this.editor;
		const tooltipCommand = editor.commands.get( 'addTooltip' );

		this._balloon.add( {
			view: this.formView,
			position: this._getBalloonPositionData()
		} );

		// Select input when form view is currently visible.
		if ( this._balloon.visibleView === this.formView ) {
			this.formView.urlInputView.select();
		}

		// Make sure that each time the panel shows up, the URL field remains in sync with the value of
		// the command. If the user typed in the input, then canceled the balloon (`urlInputView#value` stays
		// unaltered) and re-opened it without changing the value of the tooltip command (e.g. because they
		// clicked the same tooltip), they would see the old value instead of the actual value of the command.
		// https://github.com/ckeditor/ckeditor5-tooltip/issues/78
		// https://github.com/ckeditor/ckeditor5-tooltip/issues/123
		this.formView.urlInputView.inputView.element.value = tooltipCommand.value || '';
	}

	/**
	 * Closes the form view. Decides whether the balloon should be hidden completely or if the action view should be shown. This is
	 * decided upon the tooltip command value (which has a value if the document selection is in the tooltip).
	 *
	 * Additionally, if any {@tooltip module:tooltip/tooltip~TooltipConfig#decorators} are defined in the editor configuration, the state of
	 * switch buttons responsible for manual decorator handling is restored.
	 *
	 * @private
	 */
	_closeFormView() {
		const tooltipCommand = this.editor.commands.get( 'addTooltip' );

		// Restore manual decorator states to represent the current model state. This case is important to reset the switch buttons
		// when the user cancels the editing form.
		tooltipCommand.restoreManualDecoratorStates();

		if ( tooltipCommand.value !== undefined ) {
			this._removeFormView();
		} else {
			this._hideUI();
		}
	}

	/**
	 * Removes the {@tooltip #formView} from the {@tooltip #_balloon}.
	 *
	 * @protected
	 */
	_removeFormView() {
		if ( this._isFormInPanel ) {
			// Blur the input element before removing it from DOM to prevent issues in some browsers.
			// See https://github.com/ckeditor/ckeditor5/issues/1501.
			this.formView.saveButtonView.focus();

			this._balloon.remove( this.formView );

			// Because the form has an input which has focus, the focus must be brought back
			// to the editor. Otherwise, it would be lost.
			this.editor.editing.view.focus();
		}
	}

	/**
	 * Shows the correct UI type for the current state of the command. It is either
	 * {@tooltip #formView} or {@tooltip #actionsView}.
	 *
	 * @param {Boolean} forceVisible
	 * @private
	 */
	_showUI( forceVisible = false ) {
		const editor = this.editor;
		const tooltipCommand = editor.commands.get( 'addTooltip' );

		if ( !tooltipCommand.isEnabled ) {
			return;
		}

		// When there's no tooltip under the selection, go straight to the editing UI.
		if ( !this._getSelectedTooltipElement() ) {
			this._addActionsView();

			// Be sure panel with tooltip is visible.
			if ( forceVisible ) {
				this._balloon.showStack( 'main' );
			}

			this._addFormView();
		}
		// If there's a tooltip under the selection...
		else {
			// Go to the editing UI if actions are already visible.
			if ( this._areActionsVisible ) {
				this._addFormView();
			}
			// Otherwise display just the actions UI.
			else {
				this._addActionsView();
			}

			// Be sure panel with tooltip is visible.
			if ( forceVisible ) {
				this._balloon.showStack( 'main' );
			}
		}

		// Begin responding to ui#update once the UI is added.
		this._startUpdatingUI();
	}

	/**
	 * Removes the {@tooltip #formView} from the {@tooltip #_balloon}.
	 *
	 * See {@tooltip #_addFormView}, {@tooltip #_addActionsView}.
	 *
	 * @protected
	 */
	_hideUI() {
		if ( !this._isUIInPanel ) {
			return;
		}

		const editor = this.editor;

		this.stopListening( editor.ui, 'update' );
		this.stopListening( this._balloon, 'change:visibleView' );

		// Make sure the focus always gets back to the editable _before_ removing the focused form view.
		// Doing otherwise causes issues in some browsers. See https://github.com/ckeditor/ckeditor5-tooltip/issues/193.
		editor.editing.view.focus();

		// Remove form first because it's on top of the stack.
		this._removeFormView();

		// Then remove the actions view because it's beneath the form.
		this._balloon.remove( this.actionsView );
	}

	/**
	 * Makes the UI react to the {@tooltip module:core/editor/editorui~EditorUI#event:update} event to
	 * reposition itself when the editor UI should be refreshed.
	 *
	 * See: {@tooltip #_hideUI} to learn when the UI stops reacting to the `update` event.
	 *
	 * @protected
	 */
	_startUpdatingUI() {
		const editor = this.editor;
		const viewDocument = editor.editing.view.document;

		let prevSelectedTooltip = this._getSelectedTooltipElement();
		let prevSelectionParent = getSelectionParent();

		const update = () => {
			const selectedTooltip = this._getSelectedTooltipElement();
			const selectionParent = getSelectionParent();

			// Hide the panel if:
			//
			// * the selection went out of the EXISTING tooltip element. E.g. user moved the caret out
			//   of the tooltip,
			// * the selection went to a different parent when creating a NEW tooltip. E.g. someone
			//   else modified the document.
			// * the selection has expanded (e.g. displaying tooltip actions then pressing SHIFT+Right arrow).
			//
			// Note: #_getSelectedTooltipElement will return a tooltip for a non-collapsed selection only
			// when fully selected.
			if ( ( prevSelectedTooltip && !selectedTooltip ) ||
				( !prevSelectedTooltip && selectionParent !== prevSelectionParent ) ) {
				this._hideUI();
			}
			// Update the position of the panel when:
			//  * tooltip panel is in the visible stack
			//  * the selection remains in the original tooltip element,
			//  * there was no tooltip element in the first place, i.e. creating a new tooltip
			else if ( this._isUIVisible ) {
				// If still in a tooltip element, simply update the position of the balloon.
				// If there was no tooltip (e.g. inserting one), the balloon must be moved
				// to the new position in the editing view (a new native DOM range).
				this._balloon.updatePosition( this._getBalloonPositionData() );
			}

			prevSelectedTooltip = selectedTooltip;
			prevSelectionParent = selectionParent;
		};

		function getSelectionParent() {
			return viewDocument.selection.focus.getAncestors()
				.reverse()
				.find( node => node.is( 'element' ) );
		}

		this.listenTo( editor.ui, 'update', update );
		this.listenTo( this._balloon, 'change:visibleView', update );
	}

	/**
	 * Returns `true` when {@tooltip #formView} is in the {@tooltip #_balloon}.
	 *
	 * @readonly
	 * @protected
	 * @type {Boolean}
	 */
	get _isFormInPanel() {
		return this._balloon.hasView( this.formView );
	}

	/**
	 * Returns `true` when {@tooltip #actionsView} is in the {@tooltip #_balloon}.
	 *
	 * @readonly
	 * @protected
	 * @type {Boolean}
	 */
	get _areActionsInPanel() {
		return this._balloon.hasView( this.actionsView );
	}

	/**
	 * Returns `true` when {@tooltip #actionsView} is in the {@tooltip #_balloon} and it is
	 * currently visible.
	 *
	 * @readonly
	 * @protected
	 * @type {Boolean}
	 */
	get _areActionsVisible() {
		return this._balloon.visibleView === this.actionsView;
	}

	/**
	 * Returns `true` when {@tooltip #actionsView} or {@tooltip #formView} is in the {@tooltip #_balloon}.
	 *
	 * @readonly
	 * @protected
	 * @type {Boolean}
	 */
	get _isUIInPanel() {
		return this._isFormInPanel || this._areActionsInPanel;
	}

	/**
	 * Returns `true` when {@tooltip #actionsView} or {@tooltip #formView} is in the {@tooltip #_balloon} and it is
	 * currently visible.
	 *
	 * @readonly
	 * @protected
	 * @type {Boolean}
	 */
	get _isUIVisible() {
		const visibleView = this._balloon.visibleView;

		return visibleView == this.formView || this._areActionsVisible;
	}

	/**
	 * Returns positioning options for the {@tooltip #_balloon}. They control the way the balloon is attached
	 * to the target element or selection.
	 *
	 * If the selection is collapsed and inside a tooltip element, the panel will be attached to the
	 * entire tooltip element. Otherwise, it will be attached to the selection.
	 *
	 * @private
	 * @returns {module:utils/dom/position~Options}
	 */
	_getBalloonPositionData() {
		const view = this.editor.editing.view;
		const viewDocument = view.document;
		const targetTooltip = this._getSelectedTooltipElement();

		const target = targetTooltip ?
			// When selection is inside tooltip element, then attach panel to this element.
			view.domConverter.mapViewToDom( targetTooltip ) :
			// Otherwise attach panel to the selection.
			view.domConverter.viewRangeToDom( viewDocument.selection.getFirstRange() );

		return { target };
	}

	/**
	 * Returns the tooltip {@tooltip module:engine/view/attributeelement~AttributeElement} under
	 * the {@tooltip module:engine/view/document~Document editing view's} selection or `null`
	 * if there is none.
	 *
	 * **Note**: For a non–collapsed selection, the tooltip element is only returned when **fully**
	 * selected and the **only** element within the selection boundaries.
	 *
	 * @private
	 * @returns {module:engine/view/attributeelement~AttributeElement|null}
	 */
	_getSelectedTooltipElement() {
		const view = this.editor.editing.view;
		const selection = view.document.selection;

		if ( selection.isCollapsed ) {
			return findTooltipElementAncestor( selection.getFirstPosition() );
		} else {
			// The range for fully selected tooltip is usually anchored in adjacent text nodes.
			// Trim it to get closer to the actual tooltip element.
			const range = selection.getFirstRange().getTrimmed();
			const startTooltip = findTooltipElementAncestor( range.start );
			const endTooltip = findTooltipElementAncestor( range.end );

			if ( !startTooltip || startTooltip != endTooltip ) {
				return null;
			}

			// Check if the tooltip element is fully selected.
			if ( view.createRangeIn( startTooltip ).getTrimmed().isEqual( range ) ) {
				return startTooltip;
			} else {
				return null;
			}
		}
	}
}

// Returns a tooltip element if there's one among the ancestors of the provided `Position`.
//
// @private
// @param {module:engine/view/position~Position} View position to analyze.
// @returns {module:engine/view/attributeelement~AttributeElement|null} Tooltip element at the position or null.
function findTooltipElementAncestor( position ) {
	return position.getAncestors().find( ancestor => isTooltipElement( ancestor ) );
}

// https://github.com/ckeditor/ckeditor5-link/blob/186e470dd50bf9f161d4a6541360f293b4563217/src/utils.js
function isTooltipElement( node ) {
	return node.is( 'attributeElement' ) && !!node.getCustomProperty( 'tooltip' );
}
