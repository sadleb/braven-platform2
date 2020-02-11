class MajorsController < ApplicationController

  # GET /majors
  # GET /majors.json
  def index
    @majors = Major.parentless
  end

  # GET /majors/1
  # GET /majors/1.json
  def show
  end

  # GET /majors/new
  def new
  end

  # GET /majors/1/edit
  def edit
  end

  # POST /majors
  # POST /majors.json
  def create
    @major = Major.new(major_params)

    respond_to do |format|
      if @major.save
        format.html { redirect_to majors_path, notice: 'Major was successfully created.' }
        format.json { render :show, status: :created, location: @major }
      else
        format.html { render :new }
        format.json { render json: @major.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /majors/1
  # PATCH/PUT /majors/1.json
  def update
    respond_to do |format|
      if @major.update(major_params)
        format.html { redirect_to majors_path, notice: 'Major was successfully updated.' }
        format.json { render :show, status: :ok, location: @major }
      else
        format.html { render :edit }
        format.json { render json: @major.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /majors/1
  # DELETE /majors/1.json
  def destroy
    @major.destroy
    respond_to do |format|
      format.html { redirect_to majors_url, notice: 'Major was successfully deleted.' }
      format.json { head :no_content }
    end
  end

  private

    # Never trust parameters from the scary internet, only allow the white list through.
    def major_params
      params.require(:major).permit(:name, :parent_id)
    end
end
