require "option_initializer/version"

module OptionInitializer
  def self.included base
    base.const_set :OptionInitializing, Class.new {
      attr_reader :options
      alias to_h options

      def initialize base, options
        @base    = base
        @options = options
      end

      def new *args
        args = args.dup
        opts = @options

        # Convention. Deal with it.
        if args.last.is_a?(Hash)
          args[-1] = opts.merge(args.last)
        else
          args << opts.dup
        end

        @base.new(*args)
      end

      def merge opts
        self.class.new @base, @options.merge(opts)
      end

      def method_missing sym, *args
        if @base.instance_methods.include?(sym)
          @base.new(@options.dup).send sym, *args
        else
          raise NoMethodError, "undefined method `#{sym}' for #{self}"
        end
      end
    } unless base.constants.include?(:OptionInitializing)

    base.class_eval do
      def base.option_initializer *syms
        oi = self.const_get(:OptionInitializing)

        # Class methods
        syms.each do |sym|
          self.class_eval do
            # define_singleton_method not available on 1.8
            singleton = class << self; self end
            singleton.send :define_method, sym do |v|
              oi.new self, sym => v
            end
          end
        end

        # Instance methods
        oi.class_eval do
          syms.each do |sym|
            define_method(sym) do |v|
              merge(sym => v)
            end
          end
        end
      end
    end
  end
end

