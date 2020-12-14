import fetchMock from "jest-fetch-mock";
fetchMock.enableMocks();

beforeEach(() => {
  fetch.resetMocks();
});

/*
beforeEach(() => {
    // Set up our document 
    document.head.innerHTML = '<meta name="state" content="test">';
    document.body.innerHTML =
        '<input type="text" name="test-id">' +
        '<textarea name="test-id-2"></textarea>' +
        '<fieldset>' +  // start radio group
        '<div class="custom-content-radio-div">' +
        '<input type="radio" value="radio-value-1" name="radio-group-1">' +
        '</div>' +
        '<div class="custom-content-radio-div">' +
        '<input type="radio" value="radio-value-2" name="radio-group-1">' +
        '</div>' +
        '</fieldset>' +  // end radio group
        '<select name="select-1">' +  // start dropdown
        '<option value="">&nbsp;</option>' +
        '<option value="1">1</option>' +
        '</select>';  // end dropdown
});
*/

function setupHtml(projectSubmissionId, readOnly, innerHtml){
    document.head.innerHTML = '<meta name="state" content="test">';
    document.body.innerHTML =
        '<div class="container bv-lti-container">' +
          '<div class="bv-custom-content-container" id="custom-content-wrapper"' +
             `data-read-only="${readOnly}" data-project-submission-id="${projectSubmissionId}">` +
            innerHtml +
          '</div>' +
        '</div>';
}

test('prefills text input answers', async () => {
    const projectSubmissionId = 33;
    const answerId = 44;
    const inputName = 'content-name-1234';
    const inputValue = 'fellow typed something';
    setupHtml(projectSubmissionId, false, `<input type="text" name="${inputName}">`);

    // TODO: Define a mock implementation properly
    // https://www.leighhalliday.com/mock-fetch-jest
    fetch.mockResponseOnce(JSON.stringify([
        {id: answerId, project_submission_id: projectSubmissionId, input_name: inputName, input_value: inputValue}
    ]));

    const project_answers = require('packs/project_answers');
    document.dispatchEvent(new Event('DOMContentLoaded'));

    // TODO: tmp for testing
    console.log(document.body.innerHTML);

    expect(fetch).toHaveBeenCalledTimes(1);
});

/* TODO: everything is commented out. Need to re-implement without tincan.js XAPI logic. */

/*
test('set input value to matching statement response', () => {
    // Note: this has side-effects, both from top-level code and from code run during in the
    // ready callback.
    const project_answers = require('packs/project_answers');

    // Define a mock implementation.
    // https://www.leighhalliday.com/mock-fetch-jest

    // Then fire the event again, as if the document has just loaded.
    document.dispatchEvent(new Event('DOMContentLoaded'));

    // Test.
    expect(project_answers.lrs.queryStatements.mock.calls.length).toBe(1);
    expect(project_answers.lrs.moreStatements.mock.calls.length).toBe(0);
    expect(document.body.querySelector('[name="test-id"]').value).toContain('test value');
});

test('uses the first (most recent) statement', () => {
    // Note: this has side-effects, both from top-level code and from code run during in the
    // ready callback.
    const project_answers = require('packs/project_answers');

    // Define a mock implementation.
    project_answers.lrs.queryStatements.mockImplementation((cfg) => {
        const sr = real_tincan.StatementsResult.fromJSON(
            JSON.stringify({
                statements: [
                    {
                        result: {
                            response: 'latest test value'
                        },
                        target: {
                            definition: {
                                name: {
                                    und: 'test-id'
                                }
                            }
                        }
                    },
                    {
                        result: {
                            response: 'middle test value'
                        },
                        target: {
                            definition: {
                                name: {
                                    und: 'test-id'
                                }
                            }
                        }
                    },
                    {
                        result: {
                            response: 'oldest test value'
                        },
                        target: {
                            definition: {
                                name: {
                                    und: 'test-id'
                                }
                            }
                        }
                    }
                ]
            })
        );
        cfg.callback(null, sr);
    });

    // Clear the mock, so the side-effects from the ready event callback go away.
    project_answers.lrs.queryStatements.mockClear()
    // Then fire the event again, as if the document has just loaded.
    document.dispatchEvent(new Event('DOMContentLoaded'));

    // Test.
    expect(project_answers.lrs.queryStatements.mock.calls.length).toBe(1);
    expect(project_answers.lrs.moreStatements.mock.calls.length).toBe(0);
    expect(document.body.querySelector('[name="test-id"]').value).toContain('latest test value');
});

test('uses the correct matching statement when there are multiple inputs', () => {
    // Note: this has side-effects, both from top-level code and from code run during in the
    // ready callback.
    const project_answers = require('packs/project_answers');

    // Define a mock implementation.
    project_answers.lrs.queryStatements.mockImplementation((cfg) => {
        const sr = real_tincan.StatementsResult.fromJSON(
            JSON.stringify({
                statements: [
                    {
                        result: {
                            response: 'latest test value'
                        },
                        target: {
                            definition: {
                                name: {
                                    und: 'test-id'
                                }
                            }
                        }
                    },
                    {
                        result: {
                            response: 'another test value'
                        },
                        target: {
                            definition: {
                                name: {
                                    und: 'test-id'
                                }
                            }
                        }
                    },
                    {
                        result: {
                            response: 'latest test value for the textarea'
                        },
                        target: {
                            definition: {
                                name: {
                                    und: 'test-id-2'
                                }
                            }
                        }
                    },
                    {
                        result: {
                            response: 'oldest test value'
                        },
                        target: {
                            definition: {
                                name: {
                                    und: 'test-id-2'
                                }
                            }
                        }
                    }
                ]
            })
        );
        cfg.callback(null, sr);
    });

    // Clear the mock, so the side-effects from the ready event callback go away.
    project_answers.lrs.queryStatements.mockClear()
    // Then fire the event again, as if the document has just loaded.
    document.dispatchEvent(new Event('DOMContentLoaded'));

    // Test.
    expect(project_answers.lrs.queryStatements.mock.calls.length).toBe(1);
    expect(project_answers.lrs.moreStatements.mock.calls.length).toBe(0);
    expect(document.body.querySelector('[name="test-id"]').value).toContain('latest test value');
    expect(document.body.querySelector('[name="test-id-2"]').value).toContain('latest test value for the textarea');
});

test('fetches more pages if needed', () => {
    // Note: this has side-effects, both from top-level code and from code run during in the
    // ready callback.
    const project_answers = require('packs/project_answers');

    // Define a mock implementation.
    project_answers.lrs.queryStatements.mockImplementation((cfg) => {
        const sr = real_tincan.StatementsResult.fromJSON(
            JSON.stringify({
                statements: [
                    {
                        result: {
                            response: 'test value'
                        },
                        target: {
                            definition: {
                                name: {
                                    und: 'test-id'
                                }
                            }
                        }
                    }
                ],
                more: "https://example.com/more"
            })
        );
        cfg.callback(null, sr);
    });
    project_answers.lrs.moreStatements.mockImplementationOnce((cfg) => {
        const sr = real_tincan.StatementsResult.fromJSON(
            JSON.stringify({
                statements: [
                    {
                        result: {
                            response: 'test value second page'
                        },
                        target: {
                            definition: {
                                name: {
                                    und: 'test-id-no-match'
                                }
                            }
                        }
                    }
                ],
                more: "https://example.com/more/2"
            })
        );
        cfg.callback(null, sr);
    });
    project_answers.lrs.moreStatements.mockImplementation((cfg) => {
        const sr = real_tincan.StatementsResult.fromJSON(
            JSON.stringify({
                statements: [
                    {
                        result: {
                            response: 'test value third page'
                        },
                        target: {
                            definition: {
                                name: {
                                    und: 'test-id'
                                }
                            }
                        }
                    },
                    {
                        result: {
                            response: 'textarea test value third page'
                        },
                        target: {
                            definition: {
                                name: {
                                    und: 'test-id-2'
                                }
                            }
                        }
                    }
                ]
            })
        );
        cfg.callback(null, sr);
    });

    // Clear the mock, so the side-effects from the ready event callback go away.
    project_answers.lrs.queryStatements.mockClear()
    // Then fire the event again, as if the document has just loaded.
    document.dispatchEvent(new Event('DOMContentLoaded'));

    // Test.
    expect(project_answers.lrs.queryStatements.mock.calls.length).toBe(1);
    expect(project_answers.lrs.moreStatements.mock.calls.length).toBe(2);
    expect(document.body.querySelector('[name="test-id"]').value).toContain('test value');
    expect(document.body.querySelector('[name="test-id-2"]').value).toContain('textarea test value third page');
});

test('inputs are set to read-only in TA view', () => {
    // Set up our document for TA view.
    document.head.innerHTML = '<meta name="state" content="test">';
    document.body.innerHTML =
        '<div id="javascript_variables" data-project-lti-id="1" data-user-override-id="10"></div>' +
        '<input type="text" name="test-id">' +
        '<textarea name="test-id-2"></textarea>';
    // Note: this has side-effects, both from top-level code and from code run during in the
    // ready callback.
    const project_answers = require('packs/project_answers');
    // Make sure the ready event fires.
    document.dispatchEvent(new Event('DOMContentLoaded'));

    // Test.
    expect(document.body.querySelector('[name="test-id"]').disabled).toBe(true);
    expect(document.body.querySelector('[name="test-id-2"]').disabled).toBe(true);
});

test('uses the overridden student ID if it is passed in', () => {
    // Set up our document for TA view.
    document.head.innerHTML = '<meta name="state" content="test">';
    document.body.innerHTML =
        '<div id="javascript_variables" data-project-lti-id="1" data-user-override-id="10"></div>' +
        '<input type="text" name="test-id">' +
        '<textarea name="test-id-2"></textarea>';
    // Note: this has side-effects, both from top-level code and from code run during in the
    // ready callback.
    const project_answers = require('packs/project_answers');
    // Make sure the ready event fires.
    document.dispatchEvent(new Event('DOMContentLoaded'));

    // Test.
    expect(document.body.querySelector('#javascript_variables').attributes['data-user-override-id'].value).toBe("10");
    expect(project_answers.lrs.extended).toStrictEqual({user_override_id: "10"});
});

*/
