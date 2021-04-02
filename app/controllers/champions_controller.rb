# frozen_string_literal: true

# This is a part of Braven Network.
# Please don't add features to Braven Network.
# This code should be considered unsupported. We want to remove it ASAP.
class ChampionsController < ApplicationController
  layout 'braven_network'

  # Anyone can sign-up to be in the Braven Network
  skip_before_action :authenticate_user!, only: [:new, :create]

  def new
    authorize @champion
  end

  def create
    authorize Champion

    create_params = params[:champion].permit(
      :first_name,
      :last_name,
      :email,
      :phone,
      :company,
      :job_title,
      :linkedin_url,
      :region,
      :braven_fellow,
      :braven_lc,
      :willing_to_be_contacted
    )

    if params[:industries_csv] && !params[:industries_csv].empty?
      create_params[:industries] = params[:industries_csv].split(',').map(&:strip).reject(&:empty?)
    end

    if params[:studies_csv] && !params[:studies_csv].empty?
      create_params[:studies] = params[:studies_csv].split(',').map(&:strip).reject(&:empty?)
    end

    # duplicate check, if email exists, just update existing row
    @champion = Champion.create_with(create_params).find_or_create_by(email: create_params[:email])

    if !@champion.valid? || @champion.errors.any?
      render :new and return
    end

    @champion.create_or_update_on_salesforce
  end

  def connect
    authorize Champion

    @active_requests = ChampionContact.active(current_user.id)
    @max_allowed = 2 - @active_requests.count
    if @max_allowed < 0
      @max_allowed = 0
    end

    @results = []
    @search_attempted = false

    @searched_for = {}

    if params[:view_all]
      @results = Champion.all
      @search_attempted = true
    end

    if params[:interests_csv]
      @search_attempted = true
      search_terms = params[:interests_csv].split(',').map(&:strip).reject(&:empty?)

      # Add synonyms to the terms.
      synonyms = []
      search_terms.each do |term|
        ChampionSearchSynonym.where('search_term ILIKE ?', "%#{term}%").each do |synonym|
          synonyms << synonym.search_becomes
        end

        # Record stat hits, only on original terms.
        # Yes this is updating the DB on a GET, yes that means the
        # stats will be wrong, no we don't care.
        stats = ChampionStat.find_or_create_by(search_term: term)
        stats.search_count += 1
        stats.save
      end
      search_terms += synonyms

      # Search.
      search_terms.each do |s|
        @results += do_search_for_term(s)
      end
    end

    @results = @results.sort.uniq

    results_filtered = []

    # soooo this is O(n*m) but I am banking on the number of ChampionContacts being
    # somewhat small since we limit the amount of interactions any user is allowed to have
    @results.each do |result|
      found = false
      ChampionContact.where(:user_id => current_user.id).each do |ar|
        if result.id == ar.champion_id
          found = true
          break
        end
      end

      if !found
        results_filtered << result
      end
    end

   @results = results_filtered
  end

  def terms
    authorize Champion
  end

  def contact
    @other_active_requests = ChampionContact.active(current_user.id).where("id != ?", params[:id])
    cc = ChampionContact.find(params[:id])
    authorize cc, :show?

    @recipient = Champion.find(cc.champion_id)

    @hit = @recipient.industries.any? ? @recipient.industries.first : @recipient.studies.fist
    @cc = cc

    if params[:others]
      @others = params[:others]
    else
      @others = []
    end
  end

  def request_contact
    authorize Champion

    # the champion ids are passed by the user checking their boxes
    champion_ids = params[:champion_ids]

    ccs = []

    champion_ids.each do |cid|
      if ChampionContact.active(current_user.id).where(:champion_id => cid).any?
        ccs << ChampionContact.active(current_user.id).where(:champion_id => cid).first
        next
      end

      ccs << ChampionContact.create(
        :user_id => current_user.id,
        :champion_id => cid,
        :nonce => SecureRandom.base64(16)
      )
    end

    redirect_to contact_champion_path(ccs.first.id, :others => ccs[1 .. -1])
  end

  def delete_contact
    @champion_contact = ChampionContact.find(params[:id])
    authorize @champion_contact, :delete?

    @champion_contact.destroy

    redirect_to connect_champions_path
  end

  def fellow_survey
    @contact = ChampionContact.find(params[:id])
    authorize @contact

    @champion = Champion.find(@contact.champion_id)
  end

  def champion_survey
    @contact = ChampionContact.find(params[:id])
    authorize @contact

    return champion_permission_denied if !@contact.nonce.nil? && @contact.nonce != params[:nonce]
    @fellow = User.find(@contact.user_id)
  end

  def fellow_survey_save
    @contact = ChampionContact.find(params[:id])
    authorize @contact

    @contact.update(params[:champion_contact].permit(
      :champion_replied,
      :fellow_get_to_talk_to_champion,
      :why_not_talk_to_champion,
      :would_fellow_recommend_champion,
      :what_did_champion_do_well,
      :what_could_champion_improve,
      :reminder_requested,
      :inappropriate_champion_interaction,
      :fellow_comments
    ))
    if params[:champion_contact][:champion_replied] == 'true'
      @contact.reminder_requested = false
    end
    @contact.fellow_survey_answered_at = DateTime.now
    @contact.save

    if params[:champion_contact][:reminder_requested] == "true"
      @reminder_requested = true
      @reminder_email = Champion.find(@contact.champion_id).email
    end
  end

  def champion_survey_save
    @contact = ChampionContact.find(params[:id])
    authorize @contact

    return champion_permission_denied if !@contact.nonce.nil? && @contact.nonce != params[:nonce]
    @contact.update(params[:champion_contact].permit(
      :inappropriate_fellow_interaction,
      :champion_get_to_talk_to_fellow,
      :why_not_talk_to_fellow,
      :how_champion_felt_conversaion_went,
      :what_did_fellow_do_well,
      :what_could_fellow_improve,
      :champion_comments
    ))
    @contact.champion_survey_answered_at = DateTime.now
    @contact.save
  end

private

  def champion_permission_denied
    render 'champion_permission_denied', :status => :forbidden
  end

  def do_search_for_term(s)
    query = Champion.where("
      company ILIKE ?
      OR
      job_title ILIKE ?
      OR
      studies ILIKE ?
      OR
      industries ILIKE ?",
      "%#{s}%", # for company
      "%#{s}%", # for title
      "%#{s}%", # for studies
      "%#{s}%"  # for industries
    ).where(:willing_to_be_contacted => true)

    if Rails.env.production?
      query = query.where("email NOT LIKE '%+test%@bebraven.org'")
    end

    query
  end

end
