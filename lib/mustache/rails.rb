# Support for Mustache in your Rails app.
#
#   in config/environment.rb
#
#     Rails::Initializer.run do |config|
#       config.gem "mustache"
#     end
#
#   in config/initializers/mustache.rb
#
#     require "mustache/rails"
module ActionView
  class Base
    attr_reader :assigned_instance_variables

    def initialize_with_assigned_instance_variables(view_paths = [], assigns_for_first_render = {}, controller = nil)#:nodoc:
      @assigned_instance_variables = {}
      initialize_without_assigned_instance_variables(view_paths, assigns_for_first_render, controller)
    end
    alias_method_chain :initialize, :assigned_instance_variables

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
        @assigned_instance_variables[key.gsub(/^@/, "").to_sym] = value
        instance_variable_set key, value
      end
  end

  module TemplateHandlers
    class MustacheHandler < TemplateHandler
      def render(template, local_assigns)
        _compile_template(template).to_html # TODO include local_assigns
      end

      private
        # TODO refactoring
        # TODO local_assigns
        def _compile_template(template)
          klass = begin
            Mustache::Rails.classify(template).constantize
          rescue
            defined?(ApplicationView) ? ApplicationView : Mustache::Rails
          end

          klass.new(template, @view)
        end
    end
  end
end

class Mustache
  class Rails < Mustache
    @@views_path = File.expand_path(File.join(::Rails.root, "app", "views"))
    cattr_accessor :views_path

    @@templates_path = File.expand_path(File.join(::Rails.root, "app", "templates"))
    cattr_accessor :templates_path

    @@class_name_suffix = "View".freeze
    cattr_accessor :class_name_suffix

    def self.classify(template)
      "#{template.path_without_format_and_extension.classify}#{class_name_suffix}"
    end

    def initialize(template, view)
      self.template = template.filename
      @context = Context.new(view.assigned_instance_variables, self)
    end

    def template=(template)
      template = File.read(template) unless template.is_a?(Template)
      super
    end
  end

  class Context < Hash
    def initialize(hash, mustache)
      @mustache = mustache
      super()
      update(hash)
    end
  end
end

# TODO made these paths configurable by users through an initializer
ActiveSupport::Dependencies.load_paths << Mustache::Rails.views_path
ActionController::Base.view_paths       = Mustache::Rails.templates_path
ActionView::Template.register_default_template_handler :mustache, ActionView::TemplateHandlers::MustacheHandler
