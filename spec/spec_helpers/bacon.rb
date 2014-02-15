# Colorize output (based on greeneggs (c) 2009 Michael Fleet)
# TODO: Make own gem (assigned to rking)
module Bacon
  class Context
    include PryTestHelpers
  end

  COLORS    = {'F' => 31, 'E' => 35, 'M' => 33, '.' => 32}
  USE_COLOR = !(ENV['NO_PRY_COLORED_BACON'] == 'true') && Pry::Helpers::BaseHelpers.use_ansi_codes?

  module TestUnitOutput
    def handle_requirement(description)
      error = yield

      if error.empty?
        print colorize_string('.')
      else
        print colorize_string(error[0..0])
      end
    end

    def handle_summary
      puts
      puts ErrorLog if Backtraces

      out = "%d tests, %d assertions, %d failures, %d errors" %
        Counter.values_at(:specifications, :requirements, :failed, :errors)

      if Counter.values_at(:failed, :errors).inject(:+) > 0
        puts colorize_string(out, 'F')
      else
        puts colorize_string(out, '.')
      end
    end

    def colorize_string(text, color = nil)
      if USE_COLOR
        "\e[#{ COLORS[color || text] }m#{ text }\e[0m"
      else
        text
      end
    end
  end
end

# Reset top-level binding at the beginning of each test case.
module Bacon
  class Context
    def it_with_reset_binding(description, &block)
      Pry.toplevel_binding = nil
      it_without_reset_binding(description, &block)
    end
    alias it_without_reset_binding it
    alias it it_with_reset_binding
  end
end

# Support mocha
# mocha-on-bacon (c) Copyright (C) 2011, Eloy Durán <eloy.de.enige@gmail.com>
module Bacon
  module MochaRequirementsCounter
    def self.increment
      Counter[:requirements] += 1
    end
  end

  class Context
    include Mocha::API

    def it_with_mocha(description, &block)
      it_without_mocha(description) do
        begin
          mocha_setup
          block.call
          mocha_verify(MochaRequirementsCounter)
        rescue Mocha::ExpectationError => e
          raise Error.new(:failed, e.message)
        ensure
          mocha_teardown
        end
      end
    end
    alias it_without_mocha it
    alias it it_with_mocha
  end
end
