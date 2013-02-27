require "option_initializer/version"

module OptionInitializer
  def self.included base
    base.const_set :OptionInitializing, Class.new {
      attr_reader :options
      alias to_h options

      const_set :VALIDATORS, []

      def initialize base, options
        validate options
        @base    = base
        @options = options
      end

      def new *args, &block
        args = args.dup
        opts = @options

        # Convention. Deal with it.
        if args.last.is_a?(Hash)
          validate args.last
          args[-1] = opts.merge(args.last)
        else
          args << opts.dup
        end

        @base.new(*args, &block)
      end

      def merge opts
        validate opts
        self.class.new @base, @options.merge(opts)
      end

      def validate hash
        self.class.const_get(:VALIDATORS).each do |validator|
          hash.each do |k, v|
            validator.call k, v
          end
        end
      end

      def method_missing sym, *args, &block
        # 1.8
        if @base.instance_methods.map(&:to_sym).include?(sym)
          @base.new(@options.dup).send sym, *args, &block
        else
          raise NoMethodError, "undefined method `#{sym}' for #{self}"
        end
      end
    } unless base.constants.map(&:to_sym).include?(:OptionInitializing)

    base.class_eval do
      class << self
        [:option_initializer, :option_validator].each do |m|
          undef_method(m) if method_defined?(m)
        end
      end

      def base.option_validator &block
        raise ArgumentError, "block must be given" unless block
        raise ArgumentError, "invalid arity (expected: 2)" unless block.arity == 2
        oi = self.const_get(:OptionInitializing)
        oi.const_get(:VALIDATORS).push block
      end

      def base.option_initializer *syms
        oi = self.const_get(:OptionInitializing)

        # Class methods
        syms.each do |sym|
          self.class_eval do
            # define_singleton_method not available on 1.8
            singleton = class << self; self end
            singleton.send :undef_method, sym if singleton.method_defined?(sym)
            singleton.send :define_method, sym do |*v, &b|
              if b && v.empty?
                oi.new self, sym => b
              elsif b && !v.empty?
                raise ArgumentError,
                  "wrong number of arguments (#{v.length} for 0 when block given)"
              elsif v.length == 1
                oi.new self, sym => v.first
              else
                raise ArgumentError,
                  "wrong number of arguments (#{v.length} for 1)"
              end
            end
          end
        end

        # Instance methods
        oi.class_eval do
          syms.each do |sym|
            undef_method(sym) if method_defined?(sym)
            define_method(sym) do |*v, &b|
              if b && v.empty?
                merge(sym => b)
              elsif b && !v.empty?
                raise ArgumentError,
                  "wrong number of arguments (#{v.length} for 0 when block given)"
              elsif v.length == 1
                merge(sym => v.first)
              else
                raise ArgumentError,
                  "wrong number of arguments (#{v.length} for 1)"
              end
            end
          end
        end
      end
    end
  end
end

