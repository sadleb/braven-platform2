// Custom element/attribute management through the clipboard pipeline.
// This file works together with elementidediting.js.

import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import UpcastWriter from '@ckeditor/ckeditor5-engine/src/view/upcastwriter';
import Clipboard from '@ckeditor/ckeditor5-clipboard/src/clipboard';
import UniqueId from './uniqueid';
import { ELEMENT_NAME_PREFIX, ELEMENT_ID_PREFIX } from './uniqueid';

export default class ClipboardAttributeEditing extends Plugin {
    static get requires() {
        return [ UniqueId, Clipboard ];
    }

    init() {
        this._getNewId = this.editor.plugins.get('UniqueId').getNewId;
        this._getNewName = this.editor.plugins.get('UniqueId').getNewName;

        this._attachListeners();
    }

    _attachListeners() {
        // Modify clipboard contents in-transit.
        // Based on https://ckeditor.com/docs/ckeditor5/latest/framework/guides/deep-dive/clipboard.html#processing-input-content.
        // Note: this makes assumptions that all the things it's looking for are direct descendants of the $root!
        // That means, if we ever let people put a textarea inside another element, we'll need to update this code.
        this.editor.plugins.get( 'Clipboard' ).on( 'inputTransformation', ( eventInfo, data ) => {
            const writer = new UpcastWriter( this.editor.editing.view.document );
            let newContentElements = [];

            for ( const element of data.content.getChildren() ) {
                if ( [ 'textarea', 'input' ].includes( element.name ) ) {
                    const newAttributes = new Map( element.getAttributes() );
                    if ( newAttributes.has( 'name' ) && newAttributes.get( 'name' ).startsWith( ELEMENT_NAME_PREFIX ) ) {
                        newAttributes.set( 'name', this._getNewName() );
                    }

                    newContentElements.push(
                        writer.createElement(
                            element.name,
                            newAttributes,
                            element.getChildren(),
                        )
                    );
                } else if ( element.name === 'div' && element.hasClass( 'select-wrapper' ) ) {
                    // Dropdown wrapper.
                    // Expected structure is:
                    // <div class="select-wrapper">
                    //   <label for="select-id"></label>
                    //   <select id="select-id">
                    //     <option></option>
                    //   </select>
                    // </div>

                    let newChildren = [];
                    for ( const child of element.getChildren() ) {
                        if ( child.name === 'select' ) {
                            // Dropdown.
                            const newChildAttributes = new Map( child.getAttributes() );
                            if ( newChildAttributes.has( 'name' ) && newChildAttributes.get( 'name' ).startsWith( ELEMENT_NAME_PREFIX ) ) {
                                newChildAttributes.set( 'name', this._getNewName() );
                            }
                            if ( newChildAttributes.has( 'id' ) && newChildAttributes.get( 'id' ).startsWith( ELEMENT_ID_PREFIX ) ) {
                                newChildAttributes.set( 'id', this._getNewId() );
                            }

                            newChildren.push(
                                writer.createElement(
                                    child.name,
                                    newChildAttributes,
                                    child.getChildren(),
                                )
                            );
                        } else {
                            // Label.
                            newChildren.push(
                                writer.createElement(
                                    child.name,
                                    child.getAttributes(),
                                    child.getChildren(),
                                )
                            );
                        }
                    }

                    newContentElements.push(
                        writer.createElement(
                            element.name,
                            element.getAttributes(),
                            newChildren,
                        )
                    );
                } else if ( element.name === 'fieldset' && element.hasAttribute( 'data-radio-group' ) ) {
                    // Radio list.
                    const newAttributes = new Map( element.getAttributes() );
                    newAttributes.set( 'data-radio-group', this._getNewName() );

                    // Expected structure is:
                    // <fieldset>
                    //   <div>
                    //     <input>
                    //     <label></label>
                    //   </div>
                    // </fieldset>
                    let newDivs = [];
                    for ( const div of element.getChildren() ) {
                        let newChildren = [];
                        for ( const child of div.getChildren() ) {
                            if ( child.name === 'input' ) {
                                // Radio button.
                                const newRadioAttributes = new Map( child.getAttributes() );
                                if ( newRadioAttributes.has( 'name' ) && newRadioAttributes.get( 'name' ).startsWith( ELEMENT_NAME_PREFIX ) ) {
                                    // Always set the radio name to the fieldset's data-radio-group value.
                                    newRadioAttributes.set( 'name', newAttributes.get( 'data-radio-group' ) );
                                }
                                if ( newRadioAttributes.has( 'id' ) && newRadioAttributes.get( 'id' ).startsWith( ELEMENT_ID_PREFIX ) ) {
                                    newRadioAttributes.set( 'id', this._getNewId() );
                                }

                                newChildren.push(
                                    writer.createElement(
                                        child.name,
                                        newRadioAttributes,
                                    )
                                );
                            } else {
                                // Radio label.
                                newChildren.push(
                                    writer.createElement(
                                        child.name,
                                        child.getAttributes(),
                                        child.getChildren(),
                                    )
                                );
                            }
                        }

                        newDivs.push(
                            writer.createElement(
                                div.name,
                                div.getAttributes(),
                                newChildren,
                            )
                        );
                    }

                    newContentElements.push(
                        writer.createElement(
                            element.name,
                            newAttributes,
                            newDivs,
                        )
                    );
                } else if ( element.is( '$text' ) ) {
                    // Text nodes have to be handled separately, and before we check
                    // any attributes on element.name, which may be undefined.
                    newContentElements.push(
                        writer.createText(
                            element.data
                        )
                    );
                } else if ( element.name.startsWith('h') && element.name.length === 2 && !isNaN(element.name[1])) {
                    // Headings: h1, h2, h3, etc.
                    const newAttributes = new Map( element.getAttributes() );
                    if ( newAttributes.has( 'id' ) && newAttributes.get( 'id' ).startsWith( ELEMENT_ID_PREFIX ) ) {
                        newAttributes.set( 'id', this._getNewId() );
                    }

                    newContentElements.push(
                        writer.createElement(
                            element.name,
                            newAttributes,
                            element.getChildren(),
                        )
                    );
                } else {
                    // Any other content, we pass through as-is.
                    newContentElements.push(
                        writer.createElement(
                            element.name,
                            element.getAttributes(),
                            element.getChildren(),
                        )
                    );
                }
            }

            data.content = writer.createDocumentFragment( newContentElements );
        } );
    }
}
