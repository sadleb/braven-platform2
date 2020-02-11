# Helps DRY up your controllers. 
module DryCrud

  module Controllers
    extend ActiveSupport::Concern
  
    # DRY's up the show method by setting the instance variable
    # to the current instance of the module
    included do
      before_action :set_model_instance, only: [:show, :edit, :update, :destroy, :publish]
      before_action :new_model_instance, only: [:new]

    end
      
    # E.g. if your controller is called LessonsController this will set the instance variable like so:
    # @lesson = Lesson.find(params[:id]) 
    def set_model_instance
      instance_variable_set(instance_variable_name, model_class.find(params[:id]))
    end

    # E.g. if your controller is called LessonsController this will create a new @lesson instance variable
    def new_model_instance
      instance_variable_set(instance_variable_name, model_class.new)
    end

    private
      def model_class
        @model_class ||= controller_path.classify.constantize
      end

      def instance_variable_name
        @ivar_name ||= :"@#{model_class.model_name.param_key}"
      end
  end # Controllers

end # DryCrud
