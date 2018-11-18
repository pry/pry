#
# Pry::Testable::ReplTester is for super-high-level integration testing.
#
class Pry
  module Testable
    class ReplTester
      class Input
        def initialize(tester_mailbox)
          @tester_mailbox = tester_mailbox
        end

        def readline(prompt)
          @tester_mailbox.push prompt
          mailbox.pop
        end

        def mailbox
          Thread.current[:mailbox]
        end
      end

      require 'delegate'
      class Output < SimpleDelegator
        def clear
          __setobj__(StringIO.new)
        end
      end

      #
      # @example
      #   Pry::Testable::ReplTester.start do |repl|
      #     repl.enter_input '_pry_.config.prompt_name = "foo"'
      #     expect(repl.last_prompt).to match('foo')
      #   end
      #
      # @param [Hash] options
      #   A hash that is passed to {Pry#initialize}.
      #
      def self.start(options = {})
        Thread.current[:mailbox] = Queue.new
        repl_tester = new({
          input: Input.new(Thread.current[:mailbox]),
          output: Output.new(StringIO.new),
          color: false
        }.merge!(options))
        yield repl_tester
        repl_tester.ensure_exit
      ensure
        if repl_tester && repl_tester.thread && repl_tester.thread.alive?
          repl_tester.thread.kill
        end
      end

      attr_writer :last_prompt
      attr_accessor :thread, :mailbox

      #
      # @return [String]
      #   Returns the last prompt as a string.
      #
      attr_reader :last_prompt

      #
      # @return [Pry]
      #   Returns the instance of Pry being tested.
      #
      attr_reader :pry

      def initialize(options = {})
        @pry     = Pry.new(options)
        @repl    = Pry::REPL.new(@pry)
        @mailbox = Thread.current[:mailbox]

        @thread  = Thread.new do
          begin
            Thread.current[:mailbox] = Queue.new
            @repl.start
          ensure
            Thread.current[:session_ended] = true
            mailbox.push nil
          end
        end

        @should_exit_naturally = false

        wait # wait until the instance reaches its first readline
      end

      #
      # @param [String] input
      #   Accept a line of input, as if entered by a user.
      #
      # @return [void]
      #
      def enter_input(input)
        reset_output
        repl_mailbox.push input
        wait
        @pry.output.string
      end

      #
      # @return [String]
      #   Returns the last output written to `Pry#output` as a string.
      #
      def last_output
        @pry.output.string.chomp
      end

      #
      # Assert that the Pry session ended naturally after the last input.
      #
      # @return [void]
      #
      def assert_exited
        @should_exit_naturally = true
      end

      #
      # @api private
      #
      def ensure_exit
        if @should_exit_naturally
          raise "Session was not ended!" unless @thread[:session_ended].equal?(true)
        else
          enter_input "exit-all"
          raise "REPL didn't die" unless @thread[:session_ended]
        end
      end

      private

      def reset_output
        @pry.output.clear
      end

      def repl_mailbox
        @thread[:mailbox]
      end

      def wait
        @last_prompt = mailbox.pop
      end
    end
  end
end
