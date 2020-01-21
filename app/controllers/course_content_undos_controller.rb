class CourseContentUndosController < ApplicationController
  before_action :set_course_content_undo, only: [:show, :edit, :update, :destroy]

  # GET /course_content_undos
  # GET /course_content_undos.json
  def index
    @course_content_undos = CourseContentUndo.all
  end

  # GET /course_content_undos/1
  # GET /course_content_undos/1.json
  def show
  end

  # GET /course_content_undos/new
  def new
    @course_content_undo = CourseContentUndo.new
  end

  # GET /course_content_undos/1/edit
  def edit
  end

  # POST /course_content_undos
  # POST /course_content_undos.json
  def create
    @course_content_undo = CourseContentUndo.new(course_content_undo_params)

    respond_to do |format|
      if @course_content_undo.save
        format.html { redirect_to @course_content_undo, notice: 'Course content undo was successfully created.' }
        format.json { render :show, status: :created, location: @course_content_undo }
      else
        format.html { render :new }
        format.json { render json: @course_content_undo.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /course_content_undos/1
  # PATCH/PUT /course_content_undos/1.json
  def update
    respond_to do |format|
      if @course_content_undo.update(course_content_undo_params)
        format.html { redirect_to @course_content_undo, notice: 'Course content undo was successfully updated.' }
        format.json { render :show, status: :ok, location: @course_content_undo }
      else
        format.html { render :edit }
        format.json { render json: @course_content_undo.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /course_content_undos/1
  # DELETE /course_content_undos/1.json
  def destroy
    @course_content_undo.destroy
    respond_to do |format|
      format.html { redirect_to course_content_undos_url, notice: 'Course content undo was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_course_content_undo
      @course_content_undo = CourseContentUndo.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def course_content_undo_params
      params.require(:course_content_undo).permit(:course_content_id, :operation, :version, :batch_version)
    end
end
