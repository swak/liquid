module Liquid
  class PartialCache
    def self.for(*args)
      new(*args)
    end

    def initialize(context, parse_context:)
      @context = context
      @parse_context = parse_context
    end

    def load(template_name)
      cached = cached_partials[template_name]
      return cached if cached

      source = file_system.read_template_file(template_name)
      parse_context.partial = true
      Liquid::Template.parse(source, parse_context).tap do |partial|
        cached_partials[template_name] = partial
      end
    ensure
      parse_context.partial = false
    end

    private

    def cached_partials
      @cached_partials ||= begin
        context.registers[:cached_partials] ||= {}
      end
    end

    def file_system
      @file_system ||= begin
        context.registers[:file_system] ||= Liquid::Template.file_system
      end
    end

    attr_reader :context, :parse_context
  end
end
