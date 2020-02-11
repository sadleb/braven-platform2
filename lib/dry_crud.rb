# Helps DRY up your controllers. 
module DryCrud

  module Controllers
    extend ActiveSupport::Concern
  
    # DRY's up the show method by setting the instance variable
    # to the current instance of the module
    included do
      before_action :set_model_instance, only: [:show, :edit, :update, :destroy, :publish]
    end
      
    # E.g. if your controller is called LessonsController this will set the instance variable like so:
    # @lesson = Lesson.find(params[:id]) 
    def set_model_instance
      model_class = controller_path.classify.constantize
      instance_variable_set(:"@#{model_class.model_name.param_key}", model_class.find(params[:id]))
    end

  end # Controllers

end # DryCrud
