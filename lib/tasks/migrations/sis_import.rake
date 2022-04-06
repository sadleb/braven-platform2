require 'canvas_api'

namespace :sis_import do

  # With the release of the new SIS Import approach to syncing folks from
  # Salesforce to Platform and Canvas, we need to migrate all existing
  # Canvas courses to work with that logic. This is a one time task
  # to perform that migration.
  #
  # Note: migration logic of existing Sections that could be done without
  # hitting the CanvasAPI are part of the normal db/migration. See:
  # db/migrate/20220201132547_add_salesforce_id_and_type_columns_to_sections.rb
  #
  # bundle exec rake sis_import:migrate_existing
  desc "migrate existing Canvas courses to support the new SIS Import sync infrastructure"
  task migrate_existing: :environment do
    Honeycomb.start_span(name: 'sis_import.migrate_existing.rake') do

      # Turn off debug logging, we don't need to see every SQL query.
      Rails.logger.level = Logger::INFO

      # Note: these puts (and all logs) show up with app/scheduler.X in Papertrail.
      puts("### Running rake sis_import:migrate_existing - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")

      Course.where.not(canvas_course_id: nil).each do |course|
        # If you run this in your dev environment (or with your dev database)
        # it would set the incorrect IDs if you happened to have any real prod
        # courses in there. To be safe, we're restricing dev runs to only courses named
        # "XXX Playground YYY" out of the box.
        if Rails.env.production? || (Rails.env.development? && course.name =~ /Playground/)
          Honeycomb.start_span(name: 'sis_import.migrate_existing.course') do
            Honeycomb.add_field('course.id', course.id)
            Honeycomb.add_field('canvas.course.id', course.canvas_course_id)
            Honeycomb.add_field('canvas.course.name', course.name)
            program = HerokuConnect::Program.find(course.salesforce_program_id)
            Honeycomb.add_field('salesforce.program.id', course.salesforce_program_id)

            puts "\n  --> Migrating course: '#{course.name}' (id=#{course.id}, canvas_course_id=#{course.canvas_course_id}, program_id='#{course.salesforce_program_id}')"

            # Note: we don't have to migrate Canvas users SIS IDs b/c we use the
            # update_sis_id_if_login_claimed parameter which migrates the old SIS IDs
            # to the new ones for users with matching login emails.

            puts "    - setting Course SIS ID to: #{course.sis_id}"
            CanvasAPI.client.update_course(course.canvas_course_id, {'course[sis_course_id]' => course.sis_id})
            Honeycomb.add_field('canvas.course.sis_id', course.sis_id)

            # Create local TA Caseload sections. We didn't use to have
            # local sections, they only existing in Canvas.
            puts "    - ###########################################"
            puts "    - creating local TA Caseload sections for existing Canvas ones"
            sections = CanvasAPI.client.get_sections(course.canvas_course_id)
            sections.each do |section|
              if section['name'] =~ /TA Caseload/
                Honeycomb.start_span(name: 'sis_import.migrate_existing.ta_caseload.section') do
                  puts "    - processing TA Caseload Section for '#{section['name']}' (canvas_section_id=#{section['id']}, canvas_course_id=#{course.canvas_course_id})"
                  Honeycomb.add_field('canvas.section.id', section['id'])
                  Honeycomb.add_field('canvas.section.name', section['name'])
                  Honeycomb.add_field('canvas.course.sis_id', course.sis_id)
                  ta_participant = program.ta_participants.find { |ta| ta.ta_caseload_section_name == section['name'] }
                  if ta_participant.nil?
                    Honeycomb.add_field('sis_import.ta_not_found', true)
                    puts "      X - TA not found for this TA Caseload Section. Skipping"
                    next
                  end

                  # Just in case we run this again. Short circuit.
                  if Section.exists?(salesforce_id: ta_participant.sfid, course: course)
                    Honeycomb.add_field('sis_import.skip_reason', 'already migrated')
                    puts  "      X - skipping. Already done."
                    next
                  end

                  local_section = nil
                  if Section.exists?(course: course, name: section['name'])
                    # Make this re-runnable if we do a db rollback of the new Section columns (e.g. in dev)
                    local_section = Section.find_by!(course: course, name: section['name'])
                    local_section.update!(salesforce_id: ta_participant.sfid, section_type: Section::Type::TA_CASELOAD)
                  else
                    puts "    - creating new TA local Caseload Section for '#{section['name']}' (canvas_section_id=#{section['id']}, canvas_course_id=#{course.canvas_course_id})"
                    local_section = Section.create!(
                      name: section['name'],
                      course: course,
                      salesforce_id: ta_participant.sfid,
                      section_type: Section::Type::TA_CASELOAD
                    )
                  end
                  puts "      -> created new local_section (id=#{local_section.id}, salesforce_id=#{local_section.salesforce_id})"
                end
              end
            end

            # Migrate the SIS IDs in Canvas for all local Sections that already exist (note this also migrates
            # the newly created local TA Caseload sections in Canvas to have SIS IDs)
            puts "    - ###########################################"
            puts "    - migrating existing Canvas sections to have SIS IDs"
            Section.where(course: course).where.not(canvas_section_id: nil).where.not(section_type: nil).each do |section|
              Honeycomb.start_span(name: 'sis_import.migrate_existing.section') do
                Honeycomb.add_field('section.id', section.id)
                Honeycomb.add_field('canvas.section.id', section.canvas_section_id)
                Honeycomb.add_field('canvas.section.name', section.name)
                puts "    - migrating Canvas Section '#{section.name}' (canvas_section_id=#{section.canvas_section_id}, canvas_course_id=#{course.canvas_course_id}) - set SIS ID to: #{section.sis_id}"
                CanvasAPI.client.update_section(section.canvas_section_id, {'course_section[sis_section_id]' => section.sis_id})
                Honeycomb.add_field('canvas.section.sis_id', section.sis_id)
              rescue RestClient::NotFound
                Honeycomb.add_field('sis_import.skip_reason', 'section missing in Canvas')
                puts "      X - skipping. Not found in Canvas."
              end
            end

            # Create local and Canvas Sections for Cohort Schedules in the LC Playbook. We didn't use to have
            # these (only the Default Section) but now we do. They are for consistency with the Accelerator
            # and in case we want to use them to set due dates for LCs to help them see what they should
            # be doing, and when.
            if program.canvas_cloud_lc_playbook_course_id__c == course.canvas_course_id.to_s
              Honeycomb.start_span(name: 'sis_import.create_lc_playbook_cohort_schedules') do
                schedules = program.cohort_schedules
                Honeycomb.add_field('sis_import.lc_playbook_cohort_schedules', schedules.map(&:canvas_section_name))
                puts "    - ###########################################"
                puts "    - setting up Cohort Schedules for LC Playbook"
                schedules.each do |cohort_schedule|
                   # Just in case we run this again. Short circuit.
                  if Section.exists?(salesforce_id: cohort_schedule.sfid, course: course)
                    Honeycomb.add_field('sis_import.skip_reason', 'already migrated')
                    puts  "      X - skipping. Already done."
                    next
                  end

                  local_section = nil
                  puts "      -> processing Cohort Schedule '#{cohort_schedule.canvas_section_name}' (sfid='#{cohort_schedule.sfid}, canvas_course_id=#{course.canvas_course_id}')"
                  if Section.exists?(course: course, name: cohort_schedule.canvas_section_name)
                    # Make this re-runnable if we do a db rollback of the new Section columns (e.g. in dev)
                    local_section = Section.find_by!(course: course, name: cohort_schedule.canvas_section_name)
                    local_section.update!(salesforce_id: cohort_schedule.sfid, section_type: Section::Type::COHORT_SCHEDULE)
                  else
                    local_section = Section.create!(
                      name: cohort_schedule.canvas_section_name,
                      course_id: course.id,
                      salesforce_id: cohort_schedule.sfid,
                      section_type: Section::Type::COHORT_SCHEDULE
                    )
                    canvas_section = CanvasAPI.client.create_section(
                      course.canvas_course_id,
                      local_section.name,
                      local_section.sis_id
                    )
                    puts "      -> created new Canvas Cohort Schedule section: (canvas_section_id=#{canvas_section['id']}, canvas_course_id=#{course.canvas_course_id})"
                    local_section.update!(canvas_section_id: canvas_section['id'])
                  end
                  puts "        -> done! local Section (id=#{local_section.id}, sis_id: #{local_section.sis_id}, course_id=#{course.id})"
                end
              end
            end

          end
        end
      end

      puts("### Done running rake sis_import:migrate_existing - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")

    end
  rescue => e
    puts(" ### Error running rake sis_import:migrate_existing: #{e} - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
    Sentry.capture_exception(e)
    raise
  end

  # The new SIS Import infrastructure fixes some bugs with failures that happen during the
  # signup process (aka registration) and relies on the User#signup_token_sent_at field to
  # remain set even after registration in order to know if the sync of the Contact completely
  # successfully. This re-populates all existing registered users with a date for this.
  # We use the created_at date since that is generally around the time we would have sent the
  # signup_token to Salesforce but it doesn't really matter b/c the actual signup_token is now
  # nil
  # bundle exec rake sis_import:signup_tokens
  desc "migrate existing Users to have a signup_token_sent_at value"
  task signup_tokens: :environment do
    # Use Jan 1, 1970 so that if we ever need to analyze this data, we can exclude
    # these ones since they are not accurate.
    NON_SENSICAL_SENT_AT = Time.at(0).utc
    Honeycomb.start_span(name: 'sis_import.singup_tokens.rake') do
      registered_users = User.where(signup_token_sent_at: nil).where.not(registered_at: nil)
      Honeycomb.add_field('registered_users.count', registered_users.count)
      registered_users.each do |user|
        user.update(signup_token_sent_at: NON_SENSICAL_SENT_AT)
      end
    end
  end

end
