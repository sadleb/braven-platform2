import { v4 as uuidv4 } from 'uuid';
import Plugin from '@ckeditor/ckeditor5-core/src/plugin';

export const ELEMENT_ID_PREFIX = 'content-id-';
export const ELEMENT_NAME_PREFIX = 'content-name-';
export const ELEMENT_VALUE_PREFIX = 'content-value-';

/**
 * The unique ID plugin. It is used by all plugins that must create new
 * unique IDs, e.g. ElementIdEditing. This plugin is a light wrapper around
 * uuidv4(), that adds a custom prefix to returned IDs for our own convenience.
 */
export default class UniqueId extends Plugin {
    static get pluginName() {
        return 'UniqueId';
    }

    init() {
        this.getNewId = this.getNewId.bind(this);
        this.getNewName = this.getNewName.bind(this);
        this.getNewValue = this.getNewValue.bind(this);
    }

    getNewId() {
        return `${ELEMENT_ID_PREFIX}${uuidv4()}`
    }

    getNewName() {
        return `${ELEMENT_NAME_PREFIX}${uuidv4()}`
    }

    getNewValue() {
        return `${ELEMENT_VALUE_PREFIX}${uuidv4()}`
    }
}
