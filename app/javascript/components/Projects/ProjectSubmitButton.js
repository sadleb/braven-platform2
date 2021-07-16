import Rails from '@rails/ujs';
import React from "react";

import {
  Alert,
  Form,
  Button,
  Spinner,
} from 'react-bootstrap';

// Hack for half-React Projects (see packs/project_answers.js).
const WRAPPER_DIV_ID = 'custom-content-wrapper';
const SUBMISSION_DATA_ATTR = 'data-project-submission-id';
const PROJECT_SUBMISSION_ID_REGEX = /\/project_submissions\/(?<id>\d+)\//;

class ProjectSubmitButton extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      alert: null,
      // Note: we *don't* initialize this from props.hasSubmission, see
      // https://reactjs.org/docs/react-component.html#constructor for details.
      // This is a one-way flag. Once you've submitted successfully during 
      // this component's lifecycle, this is never unset. 
      hasSubmission: false,
      isSubmitting: false,
      isEnabled: true,
    };

    this._handleSubmit = this._handleSubmit.bind(this);

    // This is pretty hacky. We have a bunch of logic outside of React in project_answers.js
    // to track when answers fail to save. We need to disable the React submit button in here
    // when that happens and re-enable it after. This exposes the component on a global var so
    // we can tell this component from outside to setState({...})
    window.projectSubmitButtion = this;
  }

  toggleEnabled(value) {
    this.setState({isEnabled: value});
  }

  _handleSubmit(event) {
    event.preventDefault();

    if (this.state.isSubmitting) {
      return;
    }

    this.setState({isSubmitting: true});

    const form = event.target;
    const data = new FormData(form);

    fetch(
      `/course_project_versions/${this.props.courseContentVersionId}/project_submissions/submit`,
      {
        method: 'POST',
        body: data,
        headers: {
          'X-CSRF-Token': Rails.csrfToken(),
        },
        redirect: 'follow',
      },
     )
    .then((response) => {
      // Hack for half-React Projects.
      if (response.redirected) {
        const newProjectSubmissionId = response.url.match(PROJECT_SUBMISSION_ID_REGEX).groups.id;
        this._updateProjectSubmissionId(newProjectSubmissionId);
      }

      this.setState({
        alert: response.ok ? this._successAlert() : this._errorAlert(),
        // If you've successfully submitted this project behavior, getting 
        // an error later doesn't impact that submission. 
        hasSubmission: this.state.hasSubmission || response.ok,
        isSubmitting: false,
      });
    })
    .catch((error) => {
      this.setState({
        isSubmitting: false,
        alert: this._errorAlert(),
      });
    });
  }

  // Hack for half-React Projects (see packs/project_answers.js).
  _updateProjectSubmissionId(newProjectSubmissionId) {
    const wrapperDiv = document.getElementById(WRAPPER_DIV_ID);
    wrapperDiv.setAttribute(SUBMISSION_DATA_ATTR, newProjectSubmissionId);
  }

  _renderAlert() {
    if (!this.state.alert) {
      return;
    }
    const { heading, body, variant } = this.state.alert;
    return (
      <Alert
        className="fixed-top"
        dismissible
        onClose={() => {this.setState({alert: null})}}
        variant={variant}>
        <Alert.Heading>{heading}</Alert.Heading>
        <p>{body}</p>
      </Alert>
    );
  }

  _successAlert() {
    return {
      heading: 'Success!',
      body: 'Your changes have been saved.',
      variant: 'success',
    };
  }

  _errorAlert() {
    return {
      heading: 'Something went wrong!',
      body: 'Your changes have not been saved. Please try again.',
      variant: 'warning',
    };
  }

  _buttonSpinner() {
    return (
      <span>
        <Spinner
          className="align-middle align-center"
          hidden={!this.state.isSubmitting}
          animation="border"
          role="status"
          size="sm">
          <span className="sr-only">{this._buttonText()}</span>
        </Spinner>
        {' '}
      </span>
    );
  }

  _renderSubmitButton() {
    return (
      <Button
        block
        disabled={this.state.isSubmitting || !this.state.isEnabled}
        name="project-submit-button"
        size="lg"
        type="submit">
        {this.state.isSubmitting ? this._buttonSpinner() : null }
        {this._buttonText()}
      </Button>);
  }

  _buttonText() {
    if (this.state.isSubmitting) {
      return 'Submitting';
    }

    if (this.props.hasSubmission || this.state.hasSubmission) {
      return 'Re-Submit';
    }

    return 'Submit';
  }

  render() {
    return (
      <div>
        {this._renderAlert()}
        <Form
            inline
            onSubmit={this._handleSubmit}>
            <input
              id="state"
              name="state"
              type="hidden"
              value={this.props.ltiLaunchState}
            />
            {this._renderSubmitButton()}
        </Form>
      </div>
    );
  }
}

export default ProjectSubmitButton;
