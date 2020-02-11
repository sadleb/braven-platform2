# Helps DRY up your controllers. 
module DryCrud

  module Controllers
    extend ActiveSupport::Concern

    # DRY's up the index, show, edit, update, destroy, new, create and publish methods
    # by setting the appropriate instance variables for the corresponding model
    #
    # NOTE: you can alway override this behavior by defining whatever you want in the 
    # associated controller's index, show, edit, etc methods.
    included do
      before_action :set_models_instance, only: [:index]
      before_action :set_model_instance, only: [:show, :edit, :update, :destroy, :publish]
      before_action :new_model_instance, only: [:new]
    end 

    # Override this in any subclass that needs to turn this behavior off.
    #
    # Note: there must be a better way to do this, but I couldn't figure it out.
    # This module is included in ApplicationController and all controller inherit that,
    # so if I try to rely on respond_to?(), it applies to ApplicationController and not the subclass.
    def dry_crud_enabled?
      true
    end

  protected

    # E.g. if your controller is called LessonsController this will set the instance variable like so:
    # @lessons = Lessons.all
    def set_models_instance
      instance_variable_set(:"@#{instance_variable_name.pluralize}", model_class.all) if dry_crud_enabled? && model_class
    end

    # E.g. if your controller is called LessonsController this will set the instance variable like so:
    # @lesson = Lesson.find(params[:id]) 
    def set_model_instance
      instance_variable_set(:"@#{instance_variable_name}", model_class.find(params[:id])) if dry_crud_enabled? && model_class
    end

    # E.g. if your controller is called LessonsController this will create a new instance variable like so:
    # @lesson = Lesson.new
    def new_model_instance
      instance_variable_set(:"@#{instance_variable_name}", model_class.new) if dry_crud_enabled? && model_class
    end

  private

    def model_class
      @model_class ||= controller_path.classify.safe_constantize
    end

    def instance_variable_name
      model_class.model_name.param_key
    end

  end # Controllers

end # DryCrud
