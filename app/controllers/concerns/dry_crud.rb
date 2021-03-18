# Helps DRY up your CRUD stuffs.
module DryCrud

  # Helps DRY up your CRUD controllers
  module Controllers
    extend ActiveSupport::Concern

    # DRY's up the index, show, edit, update, destroy, new, and create methods
    # by setting the appropriate instance variables for the corresponding model
    #
    # NOTE: you can alway override this behavior by defining whatever you want in the
    # associated controller's index, show, edit, etc methods.
    included do

      potential_model_name = controller_path.classify.safe_constantize
      if potential_model_name && potential_model_name <= ActiveRecord::Base
        before_action :set_models_instance, only: [:index]
        before_action :set_model_instance, only: [:show, :edit, :update, :destroy]
        before_action :new_model_instance, only: [:new]
      else
        # No model defined. DryCrud is disabled for this controller, but it still may
        # be subclassed by a controller where it should work. Listen for that.
        def self.inherited(subclass)
          super
          potential_model_name = subclass.controller_path&.classify&.safe_constantize
          if potential_model_name && potential_model_name <= ActiveRecord::Base
            subclass.send(:before_action, :set_models_instance, only: [:index])
            subclass.send(:before_action, :set_model_instance, only: [:show, :edit, :update, :destroy])
            subclass.send(:before_action, :new_model_instance, only: [:new])
          end
        end
      end
    end

  protected

    # E.g. if your controller is called ProjectSubmissionsController this will set the instance variable like so:
    # @project_submissions = ProjectSubmissions.all
    def set_models_instance
      instance_variable_set(:"@#{instance_variable_name.pluralize}", models_list)
    end

    # E.g. if your controller is called ProjectSubmissionsController this will set the instance variable like so:
    # @project_submission = ProjectSubmission.find(params[:id])
    def set_model_instance
      instance_variable_set(:"@#{instance_variable_name}", model_class.find(params[:id]))
    end

    # E.g. if your controller is called ProjectSubmissionsController this will create a new instance variable like so:
    # @project_submission = ProjectSubmission.new
    def new_model_instance
      instance_variable_set(:"@#{instance_variable_name}", model_class.new)
    end

    # The Class of the Model that this controller operates on or nil if there is no model defined.
    def model_class
      @model_class ||= controller_path.classify.safe_constantize
    end

    def instance_variable_name
      model_class.model_name.param_key
    end

    def instance_variable
      instance_variable_get("@#{instance_variable_name}")
    end

    # This is meant to be overridden by Nestable controllers in order to
    # filter down the list to only the models for the parent resource
    def models_list
      model_class.all
    end

    # Helps with controllers for nested resources. Include this module on a controller and
    # set the parent model or an array of parent models that it could be nested under using
    # nested_resource_of.
    #
    # This will cause the index method to only load the models belonging to the parent
    # model when the route is called.
    #
    # E.g. if a Project has many ProjectSubmissions and you want the index to only list
    # ProjectSubmissions for a given Project, e.g. http://blah/project/:id/project_submissions
    # then you would add this to your ProjectSubmissionsController
    #
    # class ProjectSubmissionsController < ApplicationController
    #   include DryCrud::Controllers::Nestable
    #   nested_resource_of Project
    #   ...
    # end
    #
    # Multiple potential parents can be specified like:
    #  nested_resource_of Project, Course
    module Nestable
      extend ActiveSupport::Concern
      include Controllers

      # DRY's up the index, show, edit, update, destroy, new, and create methods
      # by setting the appropriate parent instance variable for the corresponding model
      #
      # NOTE: you can alway override this behavior by defining whatever you want in the
      # associated controller's index, show, edit, etc methods.
      included do
        delegate :parent_resource_classes, to: 'self.class'
        before_action :set_parent
      end


      class_methods do
        def nested_resource_of(classes)
          @parent_resource_classes = classes
        end

        def parent_resource_classes
          @parent_resource_classes
        end
      end

      protected

      # Looks for a parent model matching this request and sets the instance
      # if found.
      def parent
        ret = nil
        if parent_resource_classes.respond_to?(:each) # Array of nestable classes
          if klass = parent_resource_classes.detect { |pk| parent_id(pk).present? }
            ret = set_parent_instance_var(klass)
          end
        else # Single nestable class
          ret = set_parent_instance_var(parent_resource_classes)
        end
        ret
      end

      def set_parent
        @parent = parent
      end

      def set_parent_instance_var(klass)
        id = parent_id(klass)
        instance_variable_set(parent_instance_var_name(klass), klass.find(id)) if id
      end

      def parent_instance_var_name(klass)
        :"@#{klass.model_name.param_key}"
      end

      def parent_id(klass)
        params["#{klass.name.underscore}_id"]
      end

      def models_list
        if @parent.present?
          # E.g. for a CourseProjectVersion with ProjectSubmissions nested under it, this would call
          # CourseProjectVersion.send(project_submissions)
          @parent.send(model_class.name.underscore.pluralize)
        else
          super
        end
      end

    end # Nestable module

  end # Controllers

  # Helps DRY up your CRUDy Models
  module Models
  end # Models module

end # DryCrud module
