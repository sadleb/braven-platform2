# frozen_string_literal: true
#
# "Attachable" behavior for controllers like
#   - CourseResourcesController
#   - Rise360ModulesController
#
# This concern handles:
#   - #new: rendering a form for name and zipfile
#   - #create: saving the model with the zipfile attached to it

# Usage:
#
# class MyController
#   include Attachable
#
# app/views/my_models/new.html.erb:
#   <%= render partial: "attachable/form", locals: { path: my_models_path } %>
#
# This concern also relies on ActiveStorage to save the uploaded attachment:
#
# class MyModel
#   # needs to have the column 'name'
#   has_one_attached :rise360_zipfile
#

module Attachable
  extend ActiveSupport::Concern

  included do
    before_action :set_new_model_instance, only: [:new, :create]
  end

  def new
    authorize instance_variable
  end

  def create
    authorize model_class
    params.require([:name, :rise360_zipfile])
    instance_variable = model_class.create!(
      name: params[:name],
      rise360_zipfile: params[:rise360_zipfile],
    )
    redirect_to courses_path, notice: 'Rise360 zipfile was successfully uploaded.'
  end

private
  def set_new_model_instance
    instance_variable_set("@#{instance_variable_name}", model_class.new)
  end
end
