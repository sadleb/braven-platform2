import React from "react";
import { slide as Menu } from "react-burger-menu";

export default class Sidebar extends React.Component {
    constructor( props ) {
        super( props );

        this.courseContents = this.props.courseContents.map((courseContent) =>
            <a
                key={courseContent.id}
                className="menu-item"
                href={"/course_contents/" + courseContent.id + "/edit"}
            >
                {courseContent.title || "unnamed"}
            </a>
        );

    }

    render () {
        return (
            <Menu
                bodyClass={"ck-inspector-body-collapsed"}
            >
                {this.courseContents}
            </Menu>
        );
    }
}
