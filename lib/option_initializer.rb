require "option_initializer/version"

module OptionInitializer
  class OptionInitializingTemplate
    attr_reader :options
    alias to_h options

    const_set :VALIDATORS, []

    def initialize base, options, need_validation
      validate options if need_validation
      @base    = base
      @options = options
    end

    def new *args, &block
      args = args.dup
      opts = @options

      # Convention. Deal with it.
      if args.last.is_a?(Hash)
        validate args.last
        opts = opts.merge(args.last)
        args.pop
      else
        opts = opts.dup
      end

      opts.instance_eval do
        def option_validated?
          true
        end
      end
      args << opts

      @base.new(*args, &block)
    end

    def merge opts
      validate opts
      self.class.new @base, @options.merge(opts), false
    end

    def validate hash
      self.class.const_get(:VALIDATORS).each do |validator|
        hash.each do |k, v|
          validator.call k, v
        end
      end
    end
  end

  module MethodCallShortcut
    def method_missing sym, *args, &block
      # 1.8
      if @base.instance_methods.map(&:to_sym).include?(sym)
        new.send sym, *args, &block
      else
        raise NoMethodError, "undefined method `#{sym}' for #{self}"
      end
    end
  end

  def validate_options options
    raise TypeError,
      "wrong argument type #{options.class} (expected Hash)" unless
        options.is_a?(Hash)
    return if options.respond_to?(:option_validated?)
    validators = self.class.const_get(:OptionInitializing).const_get(:VALIDATORS)
    validators.each do |validator|
      options.each do |k, v|
        validator.call k, v
      end
    end
    options
  end

  def self.included base
    unless base.constants.map(&:to_sym).include?(:OptionInitializing)
      base.const_set :OptionInitializing, OptionInitializingTemplate.dup
    end

    base.class_eval do
      class << self
        [:option_initializer, :option_initializer!, :option_validator].each do |m|
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

        pairs = syms.inject([]) { |arr, sym|
          case sym
          when Symbol, String
            arr << [sym.to_sym, 1]
          when Hash
            arr.concat sym.map { |k, v|
              unless (v.is_a?(Fixnum) && v > 0) || (v.is_a?(Range) && v.begin > 0) || v == :block
                raise ArgumentError, "invalid number of arguments specified for #{k}"
              end
              [k.to_sym, v]
            }
          else
            raise ArgumentError, "invalid option specification"
          end
        }

        # Class methods
        pairs.each do |pair|
          sym = pair.first

          self.class_eval do
            # define_singleton_method not available on 1.8
            singleton = class << self; self end
            singleton.send :undef_method, sym if singleton.method_defined?(sym)
            singleton.send :define_method, sym do |*v, &b|
              oi.new(self, {}, false).send(sym, *v, &b)
            end
          end
        end

        # Instance methods
        oi.class_eval do
          pairs.each do |pair|
            sym, nargs = pair
            undef_method(sym) if method_defined?(sym)
            define_method(sym) do |*v, &b|
              case nargs
              when :block
                if b
                  if v.empty?
                    merge(sym => b)
                  else
                    raise ArgumentError, "only block expected"
                  end
                else
                  raise ArgumentError, "block expected but not given"
                end
              when 1
                if b && v.empty?
                  merge(sym => b)
                elsif b && !v.empty?
                  raise ArgumentError, "wrong number of arguments (#{v.length} for 0 when block given)"
                elsif v.length == 1
                  merge(sym => v.first)
                else
                  raise ArgumentError, "wrong number of arguments (#{v.length} for 1)"
                end
              when Range, Fixnum
                if b
                  raise ArgumentError, "block not expected"
                elsif (nargs.is_a?(Range) && !nargs.include?(v.length)) ||
                      (nargs.is_a?(Fixnum) && nargs != v.length)
                  raise ArgumentError, "wrong number of arguments (#{v.length} for #{nargs})"
                else
                  merge(sym => v)
                end
              else
                raise ArgumentError, "invalid option specification"
              end
            end
          end
        end
      end

      def base.option_initializer! *syms
        option_initializer(*syms)
        oi = self.const_get(:OptionInitializing)
        oi.class_eval do
          include OptionInitializer::MethodCallShortcut
        end
      end
    end
  end
end
