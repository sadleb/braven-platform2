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
#   def redirect_path
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
    # For app/views/attachable
    before_action :set_attachable
    before_action :set_new_model_instance, only: [:new, :create]
  end

  def new
    authorize instance_variable
  end

  def create
    authorize model_class
    instance_variable = model_class.create!(
      name: create_params[:name],
      rise360_zipfile: create_params[:rise360_zipfile],
    )
    redirect_to redirect_path, notice: 'Rise360 zipfile was successfully uploaded.'
  end

private
  def method_missing(name, *args, &block)
    raise NoMethodError, method_missing_error_msg(name) if name == :redirect_path
    super
  end

  def create_params
    params.require(instance_variable_name.to_sym).permit(:name, :rise360_zipfile)
  end

  def set_new_model_instance
    instance_variable_set("@#{instance_variable_name}", model_class.new)
  end

  def set_attachable
    @attachable = instance_variable
  end
end
