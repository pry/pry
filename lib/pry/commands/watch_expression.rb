class Pry
  class Command::WatchExpression < Pry::ClassCommand
    require 'pry/commands/watch_expression/expression.rb'
    extend Pry::Helpers::BaseHelpers

    match 'watch'
    group 'Context'
    description 'Evaluate an expression after every command and display it when its value changes.'
    command_options :use_prefix => false

    banner <<-'BANNER'
      Usage: watch [EXPRESSION]
             watch
             watch --delete [INDEX]

      Evaluate an expression after every command and display it when its value changes.
    BANNER

    def options(opt)
      opt.on :d, :delete,
        "Delete the watch expression with the given index. If no index is given; clear all watch expressions.",
        :optional_argument => true, :as => Integer
      opt.on :l, :list,
        "Show all current watch expressions and their values.  Calling watch with no expressions or options will also show the watch expressions."
    end

    def process
      ret = case
            when opts.present?(:delete)
              delete opts[:delete]
            when opts.present?(:list) || args.empty?
              list
            else
              add_hook
              add_expression(args)
            end
    end

    private

    def expressions
       state.expressions ||= []
       state.expressions
    end

    def delete(index)
      if index
        output.puts "Deleting watch expression ##{index}: #{expressions[index-1]}"
        expressions.delete_at(index-1)
      else
        output.puts "Deleting all watched expressions"
        expressions.clear
      end
    end

    def list
      if expressions.empty?
        output.puts "No watched expressions"
      else
        Pry::Pager.with_pager(output) do |pager|
          pager.puts "Listing all watched expressions:"
          pager.puts ""
          expressions.each_with_index do |expr, index|
            pager.print text.with_line_numbers(expr.to_s, index+1)
          end
          pager.puts ""
        end
      end
    end

    def eval_and_print_changed
      expressions.each do |expr|
        expr.eval!
        if expr.changed?
          output.puts "#{text.blue "watch"}: #{expr.to_s}"
        end
      end
    end

    def add_expression(arguments)
      e = expressions
      e << Expression.new(target, arg_string)
      output.puts "Watching #{Code.new(arg_string)}"
    end

    def add_hook
      hook = [:after_eval, :watch_expression]
      unless Pry.config.hooks.hook_exists? *hook
        _pry_.hooks.add_hook(*hook) do
          eval_and_print_changed
        end
      end
    end
  end

  Pry::Commands.add_command(Pry::Command::WatchExpression)
end
