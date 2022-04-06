# frozen_string_literal: true
require 'sis_import'

# Extends the base SisImport class by adding the ability to run an
# SisImport in "full batch mode". This mode is for when you want to
# overwrite everything that was previously imported for a given "term"
# with a new canonical set of data.
#
# We've run into certain situations where despite running an SisImportDataSet
# with "diffing_mode_on" turned off, Canvas doesn't properly set the enrollments,
# sections, admins, etc. This batch mode option will be in our back pockets to
# try and "repair" the ennrollments for a Program if things get in a bad state.
#
# See here for more info:
# https://github.com/bebraven/platform/wiki/Salesforce-Sync#batch-mode
class SisImportBatchMode < SisImport

  def initialize(program)
    @sis_term_id = program.sis_term_id
    Honeycomb.add_field('sis_import_batch_mode.sis_term_id', @sis_term_id)
    super()

    # This is important. A batch mode update requires a term.
    add_term(program)
  end

  # See the base SisImport class for methods to populate and send the SisImport.

private

  # Override the base class and call the full_batch_update endpoint
  def call_canvas_api(zipfile)
    CanvasAPI.client.send_sis_import_zipfile_for_full_batch_update(zipfile, @sis_term_id, change_threshold)
  end

  # Prevent accidentally deleting a ton of stuff. By default, this returns 20 which means
  # abort the sync if more than 20% of the items would be deleted.
  #
  # Set this to 100 if you wanted to blow everything away and replace it with this SisImport
  #
  # See the change_threshold docs here for more info https://canvas.instructure.com/doc/api/sis_imports.html
  def change_threshold
    return Integer(ENV['SALESFORCE_SYNC_MAX_DELETES']) if ENV['SALESFORCE_SYNC_MAX_DELETES']
    20
  end

  def additional_inspect_vars
    ", sis_term_id: '#{@sis_term_id}', change_threshold: #{change_threshold}"
  end

end

