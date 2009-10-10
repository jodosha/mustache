module ActionView
  class Base
    attr_reader :assigned_instance_variables

    private
      # Evaluates the local assigns and controller ivars, pushes them to the view.
      def _evaluate_assigns_and_ivars #:nodoc:
        unless @assigns_added
          @assigns.each { |key, value| _assign_instance_variable("@#{key}", value) }
          _copy_ivars_from_controller
          @assigns_added = true
        end
      end

      def _copy_ivars_from_controller #:nodoc:
        if @controller
          variables = @controller.instance_variable_names
          variables -= @controller.protected_instance_variables if @controller.respond_to?(:protected_instance_variables)
          variables.each { |name| _assign_instance_variable(name, @controller.instance_variable_get(name)) }
        end
      end

      def _assign_instance_variable(key, value) #:nodoc:
        @assigned_instance_variables ||= {} # FIXME it isn't threadsafe
        @assigned_instance_variables[key.gsub(/^@/, "").to_sym] = value
        instance_variable_set key, value
      end
  end

  module TemplateHandlers
    class Mustache < TemplateHandler
      def render(template, local_assigns)
        _compile_template(template).to_html # TODO include local_assigns
      end

      private
        def _compile_template(template)
          mustache = Class.new(::Mustache)
          mustache.template_file = template.filename
          mustache.attr_accessor_with_default :context, @view.assigned_instance_variables
          mustache.new
        end
    end
  end
end

ActionController::Base.view_paths = File.expand_path(File.join(Rails.root, "app", "templates"))
ActionView::Template.register_default_template_handler :mustache, ActionView::TemplateHandlers::Mustache