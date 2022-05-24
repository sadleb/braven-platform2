document.addEventListener("DOMContentLoaded", _ => {
  const addUserBtn = document.getElementById("add-btn");
  const formContainer = document.getElementById("form-container")
  const formSection = document.querySelector(".form-section");

  const cloneUser = (event) => {
    if(event.target.classList.contains("clone-btn")) {
      event.preventDefault();
      // Grab the form area you are trying to clone and duplicate it
      let targetFormSection = event.target.parentElement.parentElement;
      let clonedFormSection = targetFormSection.cloneNode(true);
      formContainer.append(clonedFormSection);
    }
  }

  // Add an empty user section to the form
  const addUser = (event) => {
    event.preventDefault();
    // Clone the initial form section
    // hide TA assignment select and cohort selects to start (shows depending on what role is selected)
    let newFormSection = formSection.cloneNode(true);
    newFormSection.querySelector('.ta-form-area').hidden = true;
    let cohort_selections = newFormSection.querySelectorAll('.cohort-area');
    cohort_selections.forEach(selection => selection.hidden = true);
    // Clear inputs and dropdowns
    newFormSection.querySelectorAll('input').forEach(formInput => {
      formInput.value = "";
    })
    newFormSection.querySelectorAll('option').forEach(option => {
      option.removeAttribute("selected");
    })
    // Add the user form section to the page
    formContainer.appendChild(newFormSection);
  }

  // Removes the 'selected' attribute from dropdown
  // Need this in case a dropdown menu gets hidden for users with a role type that shouldn't include that field
  // Ex: When a Fellow is selected they have the option to choose a TA assignment. If you start off by trying to
  // create a Fellow user, but then switch the selected role type to a TA instead, the TA assignment dropdown will
  // get hidden. If an TA assignment option had already been selected when the role was fellow, that option will
  // remain selected for the TA now even though we can no longer see the dropdown - so when the form is submitted
  // the TA will be submitted with a TA assignment, unless we remove the selected attribute from the previously
  // chosen option (this way it will get sent over as an empty string as expected).
  const removeSelected = (selectMenu) => {
    Array.from(selectMenu.options).forEach(option => {
      option.removeAttribute("selected");
    })
  }

  // Add the "selected" attribute to the option that is selected in a dropdown menu
  // Doesn't get added by default, so without this the clone feature won't work properly with the
  // selected options being chosen on the cloned user
  const addSelected = (event) => {
    if(event.target.classList.contains("select-element")) {
      let selectEl = event.target;
      // Clear previously selected options and add selected attribute to currently selected option
      removeSelected(selectEl)
      selectEl.options[selectEl.selectedIndex].setAttribute("selected","");
    }
  }

  // Reset selected item to the first option (empty string)
  const resetSelected = (selectMenu) => {
    removeSelected(selectMenu)
    selectMenu.options[0].setAttribute("selected","");
  }

  const deleteUser = (event) => {
    if(event.target.classList.contains("delete-btn")) {
      event.preventDefault();
      // Get the form section (user) that the delete was clicked for and remove it
      // Don't delete the section if it is the only section left (need at least one user in the form)
      let formSections = document.querySelectorAll('.form-section');
      if (formSections.length > 1) {
        let targetFormSection = event.target.parentElement.parentElement;
        targetFormSection.remove();
      }
    }
  }

  // Reset and disable dropdown menus that depend on another item being selected first
  const resetDropdown = (dropdown, itemToChoose) => {
    dropdown.disabled = true;
    while (dropdown.options.length > 0) {
      dropdown.remove(0);
    };
    dropdown.add(new Option(`Choose a ${itemToChoose} first`, ''));
  }

  const hideDropdownSection = (sectionToHide) => {
    // If a select menu is hidden, it shouldn't be required
    if(sectionToHide.classList.contains('cohort-schedule-area')) {
      sectionToHide.querySelector('.cohort-schedule-select').required = false;
    }
    sectionToHide.hidden = true;
    // If a select menu is hidden, it shouldn't have a selected value
    sectionToHide.querySelectorAll('option').forEach(option => {
      option.removeAttribute('selected');
    })
  }

  // Use this to hide or show certain menus depending on what type of user is being created
  // Ex: Only Fellows, LCs and CPs should see the Cohort Schedule and Cohort Section dropdown menus
  const hideOrShow = (condition, sectionToHide) => {
    if(condition) {
      sectionToHide.hidden = false;
    } else {
      hideDropdownSection(sectionToHide)
    }
  }

  // Certain dropdowns should only be enabled after other dropdowns are selected
  // Ex: Need to know the program, before we can list the cohort schedules
  const enableDropdown = (event, selectClass, disabledSelectClass, itemToChoose, fetchURL) => {
    if (!event.target.classList.contains(selectClass)) { return }
    const AUTH_HEADER = document.querySelector('meta[name="csrf-token"]').content;
    let selectedDropdownID = event.target.value;

    // Disable the dropdown that changed so that the user can't try to change the dropdown
    // again until everything in this function is done running
    event.target.disabled = true;

    // Get the disabled dropdown that you want to enable
    let targetFormSection = event.target.parentElement.parentElement;
    let disabledDropdown = targetFormSection.querySelector(disabledSelectClass);
    // Remove all options from the disabled dropdown
    resetDropdown(disabledDropdown, itemToChoose)

    // If program dropdown is changed, it clears the cohort schedule dropdown
    // so we also need to clear the cohort section dropdown and hide it
    if (selectClass == 'program-select') {
      let cohortSectionDropdown = targetFormSection.querySelector('.cohort-section-select');
      resetDropdown(cohortSectionDropdown, 'cohort schedule');
      hideDropdownSection(cohortSectionDropdown.parentElement)
      // Set disabled to false so that cohort_section params are still sent
      // for a user as an empty string, even when its hidden
      cohortSectionDropdown.disabled = false;
    }

    if (selectedDropdownID != '') {
      let selectedID = targetFormSection.querySelector(`.${selectClass}`).value;
      let fullRequestURL = `${fetchURL}/${selectedID}`
      fetch(fullRequestURL, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json;charset=utf-8',
          'Authorization': AUTH_HEADER
        },
      }).then(response => response.json())
        .then(data => {
          // Remove old selections from the dropdown and add an empty option to the top
          while (disabledDropdown.options.length > 0) {
            disabledDropdown.remove(0);
          }
          disabledDropdown.add(new Option('', ''));
          // Add new items to the dropdown.
          data.forEach(item => {
            disabledDropdown.add(new Option(`${item.name}`, `${item.id}`,));
          });
          // Enable dropdown that has new items added and the dropdown that was originally changed
          disabledDropdown.disabled = false;
          event.target.disabled = false;
        });
    }
  }

  // Only show the TA assignment select if the user being added is a Fellow
  // Only show Cohort Schedule and Cohort Section select if the user being added is a Fellow, LC or CP
  const showHideSelect = (event) => {
    if(!event.target.classList.contains("role-select") &&
      !event.target.classList.contains("cohort-schedule-select") ) { return }

    event.preventDefault();
    let targetFormSection = event.target.parentElement.parentElement;
    let cohortSection = targetFormSection.querySelector('.cohort-section-area');
    const rolesWithCohorts = ['Fellow', 'Leadership Coach', 'Coach Partner'];

    if(event.target.classList.contains('role-select')) {
      let role = event.target.value
      let taAssignment = targetFormSection.querySelector('.ta-form-area');
      let cohortSchedule = targetFormSection.querySelector('.cohort-schedule-area');
      // Show TA Assignment select for Fellows
      hideOrShow(role == 'Fellow', taAssignment);
      // Show Cohort Schedule select for Fellows and LCs
      hideOrShow(rolesWithCohorts.includes(role), cohortSchedule)

      if(rolesWithCohorts.includes(role)) {
        // For Fellows, LCs and CPs, cohort schedule select should be required
        // They need a cohort schedule to sync from Salesforce properly
        cohortSchedule.querySelector('.cohort-schedule-select').required = true;
      } else {
        // Hide Cohort Section select and TA unless user is a Fellow or LC
        // Remove the selected option so that params are sent as empty string
        hideDropdownSection(cohortSection)
        resetSelected(document.querySelector('.cohort-section-select'))
        resetSelected(document.querySelector('.ta-select'))
        resetSelected(document.querySelector('.cohort-schedule-select'))
      }
    }

    if(event.target.classList.contains('cohort-schedule-select')) {
      let cohortScheduleSelect = event.target;
      // Show Cohort Section when a Cohort Schedule is selected
      hideOrShow(cohortScheduleSelect.value != '', cohortSection)
    }
  }

  // Event Listeners
  formContainer.addEventListener("change", (event) => {
    addSelected(event);
    enableDropdown(event, 'program-select', '.cohort-schedule-select', 'program', '/test_users/cohort_schedules');
    enableDropdown(event, 'program-select', '.ta-select', 'program', '/test_users/tas');
    enableDropdown(event, 'cohort-schedule-select', '.cohort-section-select', 'cohort schedule', '/test_users/cohort_sections');
    showHideSelect(event);
  });
  formContainer.addEventListener("click", (event) => {
    cloneUser(event);
    deleteUser(event);
  })
  addUserBtn.addEventListener("click", addUser);
});
