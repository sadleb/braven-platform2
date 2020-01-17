/**
 * @license Copyright (c) 2003-2020, CKSource - Frederico Knabben. All rights reserved.
 * For licensing, see LICENSE.md or https://ckeditor.com/legal/ckeditor-oss-license
 */

/**
 * @module tooltip/tooltip
 */

import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import TooltipEditing from './tooltipediting';
import TooltipUI from './tooltipui';

/**
 * The tooltip plugin.
 *
 * This is a "glue" plugin that loads the {@tooltip module:tooltip/tooltipediting~TooltipEditing tooltip editing feature}
 * and {@tooltip module:tooltip/tooltipui~TooltipUI tooltip UI feature}.
 *
 * @extends module:core/plugin~Plugin
 */
export default class Tooltip extends Plugin {
	/**
	 * @inheritDoc
	 */
	static get requires() {
		return [ TooltipEditing, TooltipUI ];
	}

	/**
	 * @inheritDoc
	 */
	static get pluginName() {
		return 'Tooltip';
	}
}
