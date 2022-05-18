# frozen_string_literal: true

# (C) John Mair (banisterfiend) 2016
# MIT License

require "method_source"
require "coderay"

require 'pry/version'
require 'pry/exceptions'

class Pry
  autoload(:LastException, 'pry/last_exception')
  autoload(:Forwardable, 'pry/forwardable')

  autoload(:Helpers, 'pry/helpers')

  autoload(:BasicObject, 'pry/basic_object')
  autoload(:Prompt, 'pry/prompt')
  autoload(:CodeObject, 'pry/code_object')
  autoload(:Hooks, 'pry/hooks')
  autoload(:InputCompleter, 'pry/input_completer')
  autoload(:Command, 'pry/command')
  autoload(:ClassCommand, 'pry/class_command')
  autoload(:BlockCommand, 'pry/block_command')
  autoload(:CommandSet, 'pry/command_set')

  Commands = Pry::CommandSet.new unless defined?(Pry::Commands)

  autoload(:SyntaxHighlighter, 'pry/syntax_highlighter')
  autoload(:Editor, 'pry/editor')
  autoload(:History, 'pry/history')
  autoload(:ColorPrinter, 'pry/color_printer')
  autoload(:ExceptionHandler, 'pry/exception_handler')
  autoload(:SystemCommandHandler, 'pry/system_command_handler')
  autoload(:ControlDHandler, 'pry/control_d_handler')
  autoload(:CommandState, 'pry/command_state')
  autoload(:Warning, 'pry/warning')
  autoload(:Env, 'pry/env')

  autoload(:Config, 'pry/config')

  autoload(:Inspector, 'pry/inspector')
  autoload(:Pager, 'pry/pager')
  autoload(:Indent, 'pry/indent')
  autoload(:ObjectPath, 'pry/object_path')
  autoload(:Output, 'pry/output')
  autoload(:InputLock, 'pry/input_lock')
  autoload(:REPL, 'pry/repl')
  autoload(:Code, 'pry/code')
  autoload(:Ring, 'pry/ring')
  autoload(:Method, 'pry/method')
  autoload(:WrappedModule, 'pry/wrapped_module')

  autoload(:Slop, 'pry/slop')
  autoload(:CLI, 'pry/cli')
  autoload(:REPLFileLoader, 'pry/repl_file_loader')

  require 'pry/pry_class'
  require 'pry/pry_instance'
  require 'pry/core_extensions'
end
