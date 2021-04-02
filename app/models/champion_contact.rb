# frozen_string_literal: true

# This is a part of Braven Network.
# Please don't add features to Braven Network.
# This code should be considered unsupported. We want to remove it ASAP.
class ChampionContact < ActiveRecord::Base
  belongs_to :user
  belongs_to :champion

  # TODO: if we get rid of champion_surveys, change this logic. Make sure and update
  # the language about it in the connect.html.erb view where it says:
  # "The survey must be filled out by both the member of the Braven Network and Fellow"
  def self.active(user_id)

    # A request is still active until BOTH surveys are answered documenting a response
    # or until the fellow one is answered and it becomes more than a week old without
    # a response from the champion.
    ChampionContact.where(:user_id => user_id).where("
      (fellow_survey_answered_at IS NULL OR reminder_requested = true)
      OR
      (champion_survey_answered_at IS NULL AND created_at > ?)
    ", flood_prevention_cutoff_time)
  end

  def self.flood_prevention_cutoff_time
    7.days.ago.end_of_day
  end

  # We want to prevent Fellow's from abusing the system and using the survey
  # to open up more slots to request contact. Blanket rule that they have to wait a week
  def active_to_prevent_abuse
    return false if reminder_requested # They said they want to keep trying, so keep showing the contact info and survey link
    return fellow_survey_answered_at.present? && created_at > ChampionContact.flood_prevention_cutoff_time
  end

  def can_fellow_cancel?
    # only allow cancelling in the first couple minutes
    # (as a kind of "undo", though they can still farm contact info this way)
    (Time.now - created_at) < 2.minutes
  end

  def champion_email
    champion = Champion.find(champion_id)
    champion.email
  end

  def fellow_email
    user = User.find(user_id)
    user.email
  end

  def champion_email_with_name
    champion = Champion.find(champion_id)
    "#{champion.name} via The Braven Network <#{champion_email}>"
  end

  def fellow_email_with_name
    fellow = User.find(user_id)
    "#{fellow.name} via The Braven Network <#{fellow_email}>"
  end

  def self.send_reminders
    # TODO: port?
    ## if a week has passed and the fellow hasn't answered the survey yet, we email them asking them to fill it out
    ## similarly, if a week has passed after the contact request and the champion hasn't answered, we ask them too
    #items = ChampionContact.where("
    #  ((fellow_survey_answered_at IS NULL OR champion_survey_answered_at IS NULL)
    #  AND (fellow_survey_email_sent != TRUE OR champion_survey_email_sent != TRUE))
    #  AND created_at < ?",
    #  1.week.ago.end_of_day)
    #
    #items.each do |cc|
    #  if cc.fellow_survey_answered_at.nil? && !cc.fellow_survey_email_sent
    #    # remind fellow
    #    Reminders.fellow_survey_reminder(User.find(cc.user_id), cc).deliver
    #    cc.fellow_survey_email_sent = true
    #    cc.save
    #  end

    #  if cc.champion_survey_answered_at.nil? && !cc.champion_survey_email_sent
    #    # remind champion
    #    Reminders.champion_survey_reminder(Champion.find(cc.champion_id), cc).deliver
    #    cc.champion_survey_email_sent = true
    #    cc.save
    #  end
    #end
  end
end

