# option_initializer

Provides syntactic sugar for constructing objects with method chaining.

## Installation

```
gem install option_initializer
```

## Usage

```ruby
require 'option_initializer'

class Person
  include OptionInitializer

  option_initializer :id,
                     :name => String,
                     :greetings => :&,
                     :birthday => 1..3,
                     :sex => Set[:male, :female]

  option_validator :name do |v|
    raise ArgumentError, "invalid name" if v.empty?
  end

  def initialize opts
    validate_options opts
    @options = opts
  end

  def say_hello
    puts @options[:greetings].call @options[:name]
  end
end

# Then
john = Person.
         name('John Doe').
         birthday(1990, 1, 1).
         greetings { |name| "Hi, I'm #{name}!" }.
         id(1000).
         sex(:male).
         new

# becomes equivalent to
john = Person.new(
         :id => 1000,
         :name => 'John Doe',
         :birthday => [1990, 1, 1],
         :sex => :male,
         :greetings => proc { |name| "Hi, I'm #{name}!" }
       )

# Method call shortcut
class Person
  option_initializer!
end

Person.
  name('John Doe').
  age(19).
  greetings { |name| "Hi, I'm #{name}!" }.
  id(1000).
  say_hello
```

## Option definitions and validators

```ruby
class MyClass
  include OptionInitializer

  option_initializer :a,                             # Single object of any type
                     :b => 2,                        # Two objects of any type
                     :c => 1..3,                     # 1, 2, or 3 objects of any type
                     :d => :*,                       # Any number of objects of any type
                     :e => :&,                       # Block
                     :f => Fixnum,                   # Single Fixnum object
                     :g => [Fixnum, String, Symbol], # Fixnum, String, and Symbol
                     :h => Set[true, false]          # Value must be true or false

  # Validator for :f
  option_validator :f do |v|
    raise ArgumentError if v < 0
  end

  # Generic validator
  option_validator do |k, v|
    case k
    when :a
      # ...
    when :b
      # ...
    end
  end

  def initialize arg1, arg2, options
    validate_options options
    @options = options
  end
end

object = MyClass.a(o).
                 b(o1, o2).
                 c(o1, o2, o3).
                 d(o1, o2).
                 e { |o| o ** o }.
                 f(f).
                 g(f, str, sym).
                 h(true).
                 new(a1, a2)
```
