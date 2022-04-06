# frozen_string_literal: true
require 'csv'
require 'canvas_api'

# Responsible for formatting the .csvs for an Canvas SIS Import.
# Details here: https://canvas.instructure.com/doc/api/file.sis_csv.html
#
# Notes:
# - all blah_id's in here are SIS IDs.
# - if you want to use the Diffing Mode see the SisImportDataSet sub-class
# - if you want to use Batch Mode see the SisImportBatchMode sub-class
#
# See here for more info:
# https://github.com/bebraven/platform/wiki/Salesforce-Sync
class SisImport

  class Filename
    USERS_CSV='users.csv'
    TERMS_CSV='terms.csv'
    SECTIONS_CSV='sections.csv'
    ENROLLMENTS_CSV='enrollments.csv'
    ADMINS_CSV='admins.csv'
  end

  class Status
    ACTIVE='active'
    DELETED='deleted'
  end

  def initialize()
    @sis_import_id = nil
    @workflow_state = nil
    @added_section_ids = Set.new
  end

  USERS_CSV_HEADERS = ['user_id', 'login_id', 'email', 'first_name', 'last_name', 'status']

  def add_user(user, status=Status::ACTIVE)
    # Note: i had considered starting them off in a suspended state,
    # but I don't think it's worth the complexity. They won't be able to login until they
    # register and confirm their platform account and even if they could, they wouldn't see
    # anything until they were enrolled. Revisit this if we end up with a bunch of orphaned
    # accounts that we need to mark suspended for Canvas licensing purposes.
    users_csv << [
      user.sis_id,
      user.email,
      user.email,
      user.first_name,
      user.last_name,
      status
    ]
  end

  TERMS_CSV_HEADERS = ['term_id', 'name', 'status']

  def add_term(program, status=Status::ACTIVE)
    terms_csv << [
      program.sis_term_id,
      program.term_name,
      status
    ]
  end

  SECTIONS_CSV_HEADERS = ['section_id', 'course_id', 'name', 'status']

  def add_section(section, status=Status::ACTIVE)
    return if @added_section_ids.include?(section.id)
    sections_csv << [
      section.sis_id,
      section.course.sis_id,
      section.name,
      status
    ]
    @added_section_ids << section.id
  end

  ENROLLMENTS_CSV_HEADERS =  ['section_id', 'user_id', 'role', 'status', 'limit_section_privileges']

  def add_enrollment(user, section, role, limit_section_privileges=true, status=Status::ACTIVE)
    enrollments_csv << [
      section.sis_id,
      user.sis_id,
      role,
      status,
      limit_section_privileges
    ]
  end

  ADMINS_CSV_HEADERS = ['user_id', 'account_id', 'role_id', 'status']

 # We created a custom account role called "Staff Account" here:
 # https://braven.instructure.com/accounts/1/permissions
 # TAs and Staff get this. The actual Canvas "admin" role is given manually,
 # only to engineers, designers, product support, etc.
 def add_staff_account_role(user, status=Status::ACTIVE)
   admins_csv << [
      user.sis_id,
      nil, # Leave blank for the root account (aka Braven).
      CanvasConstants::STAFF_ACCOUNT_ROLE_ID,
      status
    ]
  end

  # Starts an SIS Import with the added rows and returns an SisImportStatus object
  #
  # Docs on SisImports: https://canvas.instructure.com/doc/api/sis_imports.html#SisImport
  # Docs on the file contents sent: https://canvas.instructure.com/doc/api/file.sis_csv.html
  def send_to_canvas()
    status = nil
    zipfile = nil
    Honeycomb.start_span(name: 'sis_import.send_to_canvas') do
      # The order here matters. It should be:
      # users, accounts, terms, courses, sections, enrollments, logins, (admins?)
      # See: https://community.canvaslms.com/t5/Canvas-Basics-Guide/What-are-SIS-Imports/ta-p/47

      # Inspiration for this Zipfile approach taken from here:
      # https://www.devinterface.com/en/blog/create-file-zip-on-the-fly-with-ruby
      # Note: xxx_csv.string is the same thing that generate() would return
      zipfile = Tempfile.new(['sis_import_', '.zip'])
      Zip::OutputStream.open(zipfile.path) do |zip|
        zip.put_next_entry(Filename::USERS_CSV)
        zip << users_csv.string
        zip.put_next_entry(Filename::TERMS_CSV)
        zip << terms_csv.string
        zip.put_next_entry(Filename::SECTIONS_CSV)
        zip << sections_csv.string
        zip.put_next_entry(Filename::ENROLLMENTS_CSV)
        zip << enrollments_csv.string
        zip.put_next_entry(Filename::ADMINS_CSV)
        zip << admins_csv.string
      end

      status = call_canvas_api(zipfile)

      @sis_import_id = status.sis_import_id
      Honeycomb.add_field('canvas.sis_import.id', @sis_import_id.to_s)
      @workflow_state = status.workflow_state
      Honeycomb.add_field('canvas.sis_import.workflow_state', @workflow_state)
      Rails.logger.debug('SIS Import sent to Canvas:')
      # Note: we can't send the .csvs to Honeycomb b/c they can be too big and overflow the
      # 64K max size for a string field.
      Rails.logger.debug(inspect)
    end

    status
  ensure
    zipfile.close
    zipfile.unlink   # deletes the temp file
  end

  def inspect
    ret = StringIO.new
    ret << "#<#{self.class.name} sis_import_id: #{@sis_import_id}, workflow_state='#{@workflow_state}'#{additional_inspect_vars}>"

    ret << "\n -> #{Filename::USERS_CSV}:\n"
    ret << users_csv.string

    ret << "\n -> #{Filename::TERMS_CSV}:\n"
    ret << terms_csv.string

    ret << "\n -> #{Filename::SECTIONS_CSV}:\n"
    ret << sections_csv.string

    ret << "\n -> #{Filename::ENROLLMENTS_CSV}:\n"
    ret << enrollments_csv.string

    ret << "\n -> #{Filename::ADMINS_CSV}:\n"
    ret << admins_csv.string

    ret << "\n"
    ret.string
  end

private

  def users_csv
    @users_csv ||= CSV.new(StringIO.new, headers: USERS_CSV_HEADERS, write_headers: true)
  end

  def terms_csv
    @terms_csv ||= CSV.new(StringIO.new, headers: TERMS_CSV_HEADERS, write_headers: true)
  end

  def sections_csv
    @sections_csv ||= CSV.new(StringIO.new, headers: SECTIONS_CSV_HEADERS, write_headers: true)
  end

  def enrollments_csv
    @enrollments_csv ||= CSV.new(StringIO.new, headers: ENROLLMENTS_CSV_HEADERS, write_headers: true)
  end

  def admins_csv
    @admins_csv ||= CSV.new(StringIO.new, headers: ADMINS_CSV_HEADERS, write_headers: true)
  end

  def add_csv_to_sis_import(filename, csv)
    # Inspiration for this approach taken from here:
    # https://www.devinterface.com/en/blog/create-file-zip-on-the-fly-with-ruby
    Zip::OutputStream.open(zipfile.path) do |zip|
      zip.put_next_entry(filename)
      zip << csv.string # this is the same thing that generate() would return
    end
  end

  def call_canvas_api(zipfile)
    raise NotImplementedError.new(
      "You must override the call_canvas_api(zipfile) method in #{self.class.name} with the logic " +
      "to actually call the proper CanvasAPI endpoint and return an SisImportStatus object."
    )
  end

  # Override me with a string to add more instance variable info to #inspect
  def additional_inspect_vars
    ''
  end
end

