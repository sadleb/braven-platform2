// Pop-window rendered by linked_in_authorization#launch
//
// We need a new window because LinkedIn won't allow us to embed the 
// authorization flow in an iframe (e.g., how we render Projects in Canvas
// that would display a link to this flow). 
// 
// Note: This component modifies the current browser window. The caller must
// set up a new window if it doesn't want the existing one clobbered.

import Rails from '@rails/ujs';
import React from "react";

class LinkedInAuthorizationWindow extends React.Component {
  constructor(props) {
    super(props);
  }

  render() {
    // If there's no URL to display, user has gone through the LinkedIn
    // authorization flow and the controller has handled the accept/reject
    // from them.
    if (!this.props.displayUrl) {
      const params = (new URL(window.location)).searchParams;
      if (params.has('error')) {
        // The user declined the authorization, or some other error
        // occured. They've already been informed about the error
        // by the LinkedIn flow, so we can just close immediately.
        window.close();
        return null;
      } else {
        // Briefly show a success message before we shut down the
        // pop-up.
        setTimeout(function(){ window.close(); }, 5000);
        return <div>
          <h1>Success!</h1>
          <p>You authorized Braven to access your LinkedIn data.</p>
          <p>You can now close this window, or it will close automatically in a few seconds.</p>
        </div>;
      }
    }

    // Render LinkedIn's authorization page in pop-up
    window.location = this.props.displayUrl;

    return null; // Rendering handled above, return something by convention
  }
}

export default LinkedInAuthorizationWindow;
