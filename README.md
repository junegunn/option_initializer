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
  option_initializer :id, :name, :age, :greetings
  option_validator do |k, v|
    case k
    when :age
      raise ArgumentError, "invalid age" if v < 0
    when :name
      raise ArgumentError, "invalid name" if v.empty?
    end
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
         age(19).
         greetings { |name| "Hi, I'm #{name}!" }.
         id(1000).
         new

# becomes equivalent to
john = Person.new(
         :id => 1000,
         :name => 'John Doe',
         :age => 19,
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

