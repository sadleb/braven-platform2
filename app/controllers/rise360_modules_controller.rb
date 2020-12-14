# frozen_string_literal: true

class Rise360ModulesController < ApplicationController
  include DryCrud::Controllers

  # Add the #new and #create actions
  include Attachable

  layout 'admin'

  def index
    authorize Rise360Module
    @rise360_modules = Rise360Module.all.order(updated_at: :desc)
  end

  def edit
    authorize @rise360_module
  end

  def update
    authorize @rise360_module

    @rise360_module.update!(
      name: create_params[:name],
    )

    @rise360_module.rise360_zipfile.attach(create_params[:rise360_zipfile]) if create_params[:rise360_zipfile]

    respond_to do |format|
      format.html { redirect_to redirect_path, notice: 'Module was successfully updated.' }
      format.json { head :no_content }
    end
  end

  def destroy
    authorize @rise360_module
    @rise360_module.destroy!
    respond_to do |format|
      format.html { redirect_to redirect_path, notice: 'Module was successfully deleted.' }
      format.json { head :no_content }
    end
  end

private
  # For attachable
  def redirect_path
    rise360_modules_path
  end
end
