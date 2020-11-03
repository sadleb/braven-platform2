class CustomContentsController < ApplicationController
  layout 'content_editor'
  before_action :set_custom_contents, only: [:index, :edit, :new]

  # GET /custom_contents
  # GET /custom_contents.json
  def index
    authorize custom_content_class
  end

  # GET /custom_contents/1
  # GET /custom_contents/1.json
  def show
    authorize @custom_content
  end

  # GET /custom_contents/new
  def new
    @custom_content = custom_content_class.new
    authorize @custom_content
  end

  # GET /custom_contents/1/edit
  def edit
    authorize @custom_content
  end

  # POST /custom_contents
  # POST /custom_contents.json
  def create
    @custom_content = custom_content_class.new(custom_content_params)
    authorize @custom_content

    respond_to do |format|
      if @custom_content.save
        format.html { redirect_to edit_custom_content_path(@custom_content), notice: 'CustomContent was successfully created.' }
        format.json { render :show, status: :created, location: @custom_content }
      else
        format.html { render :new }
        format.json { render json: @custom_content.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /custom_contents/1
  # PATCH/PUT /custom_contents/1.json
  def update
    authorize @custom_content

    respond_to do |format|
      if @custom_content.update(update_custom_content_params)
        format.html { redirect_to edit_custom_content_path(@custom_content), notice: 'CustomContent was successfully updated.' }
        format.json { render :show, status: :ok, location: @custom_content }
      else
        format.html { render :edit }
        format.json { render json: @custom_content.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /custom_contents/1
  # DELETE /custom_contents/1.json
  def destroy
    authorize @custom_content
    @custom_content.destroy
    respond_to do |format|
      format.html { redirect_to custom_contents_url, notice: 'CustomContent was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def self.class_from_type(type)
    case type
    when nil
      CustomContent
    when 'Project'
      Project
    when 'Survey'
      Survey
    else
      raise TypeError.new "Unknown CustomContent type: #{type}"
    end
  end

  private
  def set_custom_contents
    @custom_contents = custom_content_class.all
  end

  # Always use the following to create a CustomContent object:
  #   custom_content_class.new
  # **never** use unsafe `type` from the parameters, e.g.:
  #   CustomContent.{new, update}(type: params[:type]) # BAD!
  def custom_content_class
    # Prefer `type` specified by form over the one set in route parameters
    type = params[:custom_content] ? params[:custom_content][:type] : params[:type]
    CustomContentsController.class_from_type(type)
  end

  # We always use `custom_content_class.new`, which specifies the subclass
  # name instead of passing in `type`, so we remove `type` from the 
  # parameters here
  def custom_content_params
    params.require(:custom_content).except(:type).permit(
      :title,
      :body,
      :published_at,
      :course_id,
      :course_name,
      :secondary_id,
    )
  end

  def update_custom_content_params
    update_params = custom_content_params
    # Only update `type` from non-nil to non-nil value
    update_params[:type] = custom_content_class.to_s if !@custom_content.type && custom_content_class.to_s != 'CustomContent'
    update_params
  end
end
