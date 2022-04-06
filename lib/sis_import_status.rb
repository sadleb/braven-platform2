# frozen_string_literal: true
require 'canvas_api'
require 'sis_import'

# Reprsents the status of an SIS Import returned from the CanvasAPI.
# Provides utility methods to wait on an import to finish as well as
# instrumentation and helper methods to analyze the result.
#
# Canvas docs: https://canvas.instructure.com/doc/api/sis_imports.html
#
# See here for more info:
# https://github.com/bebraven/platform/wiki/Salesforce-Sync
class SisImportStatus

  # How long to sleep between polling to see if the SIS Import finished.
  # chosen arbitrarily
  POLLING_WAIT_TIME_SECONDS=5

  class WorkflowState
    INITIALIZING='initializing'
    CREATED='created'
    IMPORTING='importing'
    CLEANUP_BATCH='cleanup_batch'
    RESTORING='restoring'
    IMPORTED='imported'
    IMPORTED_WITH_MESSAGES='imported_with_messages'
    ABORTED='aborted'
    FAILED_WITH_MESSAGES='failed_with_messages'
    FAILED='failed'
    PARTIALLY_RESTORED='partially_restored'
    RESTORED='restored'
  end

  class ErrorType
    USER_MISSING=:user_missing
  end

  # Initialize me with the response from SisImportDataSet#send_to_canvas()
  # This is a Canvas SisImport object:
  # https://canvas.instructure.com/doc/api/sis_imports.html#SisImport
  def initialize(sis_import)
    @sis_import = sis_import
  end

  def sis_import_id
    @sis_import_id ||= @sis_import['id']
  end

  def workflow_state
    @workflow_state ||= @sis_import['workflow_state']
  end

  # Returns true if the full import was successful with no errors.
  # Use is_success_with_errors? for when the import was partially successful,
  # but there were errors for some rows.
  def is_success?
    workflow_state == WorkflowState::IMPORTED
  end

  # If true, the overall import was successful but there were errors processing some rows.
  #
  # See processing_error_details for more info.
  def is_success_with_errors?
    workflow_state == WorkflowState::IMPORTED_WITH_MESSAGES
  end

  # These are the states that mean the import is running. We use this instead of progress
  # b/c progress will be 0 for states like 'failed'
  def is_running?
    [
      WorkflowState::INITIALIZING,
      WorkflowState::CREATED,
      WorkflowState::IMPORTING,
      WorkflowState::CLEANUP_BATCH,
      WorkflowState::RESTORING
    ].include?(workflow_state)
  end

  def created_at
    @created_at ||= @sis_import['created_at']
  end

  def ended_at
    @ended_at ||= @sis_import['ended_at']
  end

  def progress
    @progress ||= @sis_import['progress']
  end

  def processing_warnings
    @processing_warnings ||= @sis_import['processing_warnings']
  end

  def processing_errors
    @processing_errors ||= @sis_import['processing_errors']
  end

  # Array of hashes with the details for each error:
  # E.g.
  # [
  #   { :file_name: 'users.csv', :message => 'An error message' }, # No extra parsing implemented yet.
  #   {
  #     :file_name: 'admins.csv', :message => 'Other error message',
  #     :contact_id => '<the_contact_id>', :error_type => :user_missing
  #   }
  # ]
  #
  # Note: we only implement parsing out more details than the error message for those that
  # we have to handle differently.
  def processing_error_details
    @processing_error_details ||= begin
      error_details = []

      processing_errors&.each do |e|
        # Standard parsing for all errors:
        #
        file_name = e[0]
        message = e[1]
        details = { file_name: file_name, message: message }

        # Extra parsing for errors we need to handle differently.
        #
        user_missing_match_data = /unknown user_id 'BVUserId_\d+_SFContactId_(?<contact_id>[a-zA-Z0-9]{18})'/.match(message)
        contact_id = user_missing_match_data&.named_captures['contact_id']
        details.merge!({contact_id: contact_id, error_type: ErrorType::USER_MISSING}) if contact_id

        error_details << details
      end

      error_details
    end
  end

  def errors_attachment_url
    @errors_attachment_url ||= @sis_import.dig('errors_attachment', 'url')
  end

  def error_message
    @error_message ||= data&.dig('error_message')
  end

  def data
    @data ||= @sis_import['data']
  end

  # Poll Canvas waiting for an SIS Import to finish running.
  # Yields to the block passed on each loop of the polling so
  # that consumers can exit early if it takes too long.
  #
  # Returns the final SisImportStatus object with the status
  def wait_for_import_to_finish()
    sis_import_status = self
    while sis_import_status.is_running?
      Honeycomb.start_span(name: 'sis_import_status.wait_for_import_to_finish') do
        sis_import_status.add_to_honeycomb_span

        # About to sleep, so let the consumer raise an error if it's been too long
        yield if block_given?

        sleep POLLING_WAIT_TIME_SECONDS
        sis_import_status = CanvasAPI.client.get_sis_import_status(sis_import_status.sis_import_id)
      end
    end

    sis_import_status
  end

  def add_to_honeycomb_span
    Honeycomb.add_field('canvas.sis_import.id', sis_import_id.to_s)
    Honeycomb.add_field('canvas.sis_import.workflow_state', workflow_state)
    Honeycomb.add_field('canvas.sis_import.created_at', created_at)
    Honeycomb.add_field('canvas.sis_import.ended_at', ended_at)
    Honeycomb.add_field('canvas.sis_import.progress', progress)
    Honeycomb.add_field('canvas.sis_import.processing_warnings', processing_warnings)
    Honeycomb.add_field('canvas.sis_import.processing_errors', processing_errors)
    Honeycomb.add_field('canvas.sis_import.errors_attachment.url', errors_attachment_url)
    Honeycomb.add_field('canvas.sis_import.error_message', error_message)

    Rails.logger.debug(self.inspect)
  end

  def inspect
    ret = StringIO.new
    ret << "#<SisImportStatus sis_import_id: #{sis_import_id}, workflow_state: '#{workflow_state}', created_at: '#{created_at}', ended_at: '#{ended_at}', progress: '#{progress}'>"
    ret << "\n -> Error: #{error_message}" if error_message
    ret << "\n -> errors_attachment_url: #{errors_attachment_url}" if errors_attachment_url
    ret << "\n -> processing_warnings: #{processing_warnings}" if processing_warnings
    ret << "\n -> processing_errors: #{processing_errors}" if processing_errors
    ret << "\n -> data: #{data}" if data
    ret << "\n"
    ret.string
  end

 end
