# frozen_string_literal: true
require 'sis_import'

# Extends the base SisImport class by adding the ability to associate the import
# with a data-set. A data-set has an ID and each import sent with that ID is considered
# the canonical set of data and anything missing from prior imports for that data-set
# will be REMOVED.
#
# See here for more info:
# https://github.com/bebraven/platform/wiki/Salesforce-Sync#datasets-and-diffing
class SisImportDataSet < SisImport

  # For a given data_set_id if any information is missing from a previous import, it will
  # be DELETED from Canvas. Each Salesforce Program uses a unique data_set_id to send
  # a snapshot of all Canvas user, section, enrollment, etc data for each sync -> thus
  # avoiding the logic around what to remove or change.
  #
  # If there are failures, you MUST set the diffing_mode_on parameter false in subsequent syncs
  # until the failures are fixed. This turns off the "diffing" logic of the SIS Import API
  # so that the whole batch is processed. Canvas isn't smart enough to do a diff to the last
  # successful import
  def initialize(program, diffing_mode_on)
    @data_set_id = program.sis_import_data_set_id
    @diffing_mode_on = diffing_mode_on
    Honeycomb.add_field('sis_import_data_set.id', @data_set_id)
    Honeycomb.add_field('sis_import_data_set.diffing_mode_on', @diffing_mode_on)
    super()

    # This is important so that we can use an SisImportBatchMode to repair
    # the information for a Program.
    add_term(program)
  end

  # See the base SisImport class for methods to populate and send the SisImport.

private

  # Override the base class and call the data_set endpoint
  def call_canvas_api(zipfile)
    CanvasAPI.client.send_sis_import_zipfile_for_data_set(zipfile, @data_set_id, @diffing_mode_on)
  end

  def additional_inspect_vars
    ", data_set_id: '#{@data_set_id}', diffing_mode_on: #{@diffing_mode_on}"
  end

end

