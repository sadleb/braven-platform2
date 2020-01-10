import React from 'react';

export default class ContentPartPreview extends React.Component {
    render() {
        return (
            <li
                onClick={() => this.props.onClick( this.props.id )}
                title="Add to the editor"
            >
                {this.props.name}
            </li>
        );
    }
}
