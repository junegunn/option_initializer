require 'option_initializer/version'
require 'set'

unless Class.respond_to?(:|)
  class Class
    def | other_class
      unless other_class.is_a?(Class)
        raise TypeError, "wrong argument type (expected: Class)"
      end
      OptionInitializer::ClassMatch.new(self, other_class)
    end
  end
else
  Kernel.warn "Class already has `|' method. OptionInitializer will not override its behavior."
end

module OptionInitializer
  class ClassMatch
    def initialize *classes
      @classes = Set[*classes]
    end

    def | other_class
      unless other_class.is_a?(Class)
        raise TypeError, "wrong argument type (expected: Class)"
      end
      ClassMatch.new(*@classes.union([other_class]))
    end

    def match object
      @classes.any? { |k| object.is_a? k }
    end

    def to_s
      a = @classes.map(&:to_s)
      [a[0...-1].join(', '), a.last].reject(&:empty?).join(', or ')
    end
  end

  # @private
  class OptionInitializingTemplate
    attr_reader :options
    alias to_h options

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
      avals, vals = [:ARG_VALIDATORS, :VALIDATORS].map { |s|
        self.class.const_get(s)
      }
      hash.each do |k, v|
        avals[k]  && avals[k].call(v)
        vals[k]   && vals[k].call(v)
        vals[nil] && vals[nil].call(k, v)
      end
    end
  end

  # @private
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
    return if options.respond_to?(:option_validated?) && options.option_validated?
    avals, vals = [:ARG_VALIDATORS, :VALIDATORS].map { |s|
      self.class.const_get(:OptionInitializing).const_get(s)
    }
    options.each do |k, v|
      avals[k]  && avals[k].call(v)
      vals[k]   && vals[k].call(v)
      vals[nil] && vals[nil].call(k, v)
    end
    options
  end

  # @private
  def self.included base
    unless base.constants.map(&:to_sym).include?(:OptionInitializing)
      base.const_set :OptionInitializing, oi = OptionInitializingTemplate.dup
      oi.class_eval do
        const_set :VALIDATORS, {}
        const_set :ARG_VALIDATORS, {}
      end
    end

    base.class_eval do
      class << self
        [:option_initializer, :option_initializer!, :option_validator].each do |m|
          undef_method(m) if method_defined?(m)
        end
      end

      def base.option_validator sym = nil, &block
        raise ArgumentError, "block must be given" unless block
        a = sym ? 1 : 2
        raise ArgumentError, "invalid arity (expected: #{a})" unless block.arity == a
        oi = self.const_get(:OptionInitializing)
        oi.const_get(:VALIDATORS)[sym] = block
      end

      def base.option_initializer *syms
        oi = self.const_get(:OptionInitializing)

        pairs = syms.inject([]) { |arr, sym|
          case sym
          when Symbol, String
            arr << [sym.to_sym, 1]
          when Hash
            arr.concat sym.map { |k, v|
              case v
              when Fixnum
                raise ArgumentError, "invalid number of arguments specified for #{k}" if v <= 0
              when Range
                raise ArgumentError, "invalid number of arguments specified for #{k}" if v.begin < 0
              when Set
                raise ArgumentError, "empty set of values specified for #{k}" if v.length == 0
              when Array
                unless v.all? { |e| [Class, Set, ClassMatch].any? { |kl| e.is_a?(kl) } }
                  raise ArgumentError, "invalid option definition: `#{v}'"
                end
              when Class, :*, :&
                # noop
              when ClassMatch
                # noop
              else
                raise ArgumentError, "invalid option definition: `#{v}'"
              end
              [k.to_sym, v]
            }
          else
            raise ArgumentError, "invalid option definition"
          end
        }

        # Setup validators
        vals = oi.const_get(:ARG_VALIDATORS)
        pairs.each do |pair|
          sym, nargs = pair
          case nargs
          when :&
            vals[sym] = proc { |v|
              if !v.is_a?(Proc)
                raise TypeError, "wrong argument type #{v.class} (expected Proc)"
              end
            }
          when 1
            # good to go
            vals.delete sym
          when :*
            vals[sym] = proc { |v|
              if !v.is_a?(Array)
                raise ArgumentError, "wrong number of arguments (1 for #{nargs})"
              end
            }
          when Fixnum
            vals[sym] = proc { |v|
              if !v.is_a?(Array)
                raise ArgumentError, "wrong number of arguments (1 for #{nargs})"
              elsif nargs != v.length
                raise ArgumentError, "wrong number of arguments (#{v.length} for #{nargs})"
              end
            }
          when Range
            vals[sym] = proc { |v|
              if !v.is_a?(Array)
                raise ArgumentError, "wrong number of arguments (1 for #{nargs})"
              elsif !nargs.include?(v.length)
                raise ArgumentError, "wrong number of arguments (#{v.length} for #{nargs})"
              end
            }
          when Set
            vals[sym] = proc { |v|
              if !nargs.include?(v)
                raise ArgumentError, "invalid option value: `#{v}' (expected one of #{nargs.to_a.inspect})"
              end
            }
          when Array
            vals[sym] = proc { |v|
              if !v.is_a?(Array)
                raise ArgumentError, "wrong number of arguments (1 for #{nargs.length})"
              elsif nargs.length != v.length
                raise ArgumentError, "wrong number of arguments (#{v.length} for #{nargs.length})"
              else
                v.zip(nargs).each do |ec|
                  e, c = ec
                  case c
                  when Class
                    raise TypeError, "wrong argument type #{e.class} (expected #{c})" unless e.is_a?(c)
                  when Set
                    unless c.include?(e)
                      raise ArgumentError, "invalid option value: `#{e}' (expected one of #{c.to_a.inspect})"
                    end
                  when ClassMatch
                    unless c.match e
                      raise TypeError, "wrong argument type #{e.class} (expected #{c})"
                    end
                  end
                end
              end
            }
          when Class
            vals[sym] = proc { |v|
              if !v.is_a?(nargs)
                raise TypeError, "wrong argument type #{v.class} (expected #{nargs})"
              end
            }
          when ClassMatch
            vals[sym] = proc { |v|
              unless nargs.match v
                raise TypeError, "wrong argument type #{v.class} (expected #{nargs})"
              end
            }
          end
        end

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
              if nargs == :&
                if v.empty?
                  merge(sym => b)
                else
                  raise ArgumentError, "wrong number of arguments (#{v.length} for 0)"
                end
              elsif b
                raise ArgumentError, "block not expected"
              else
                case nargs
                when 1, Class, Set, ClassMatch
                  if v.length == 1
                    merge(sym => v.first)
                  else
                    raise ArgumentError, "wrong number of arguments (#{v.length} for 1)"
                  end
                else
                  merge(sym => v)
                end
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
