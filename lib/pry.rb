# frozen_string_literal: true

# (C) John Mair (banisterfiend) 2010
# MIT License

require 'pry/version'
require 'pry/last_exception'
require 'pry/forwardable'

require 'pry/helpers/base_helpers'
require 'pry/helpers/documentation_helpers'
require 'pry/helpers'

require 'pry/basic_object'
require 'pry/prompt'
require 'pry/code_object'
require 'pry/exceptions'
require 'pry/hooks'
require 'pry/input_completer'
require 'pry/command'
require 'pry/class_command'
require 'pry/block_command'
require 'pry/command_set'
require 'pry/syntax_highlighter'
require 'pry/editor'
require 'pry/history'
require 'pry/color_printer'
require 'pry/exception_handler'
require 'pry/system_command_handler'
require 'pry/control_d_handler'
require 'pry/command_state'
require 'pry/warning'
require 'pry/env'

Pry::Commands = Pry::CommandSet.new unless defined?(Pry::Commands)

require 'pry/commands/ls/config'
require 'pry/commands/ls/jruby_hacks'
require 'pry/commands/ls/methods_helper'
require 'pry/commands/ls/interrogatable'
require 'pry/commands/ls/grep'
require 'pry/commands/ls/formatter'
require 'pry/commands/ls/globals'
require 'pry/commands/ls/constants'
require 'pry/commands/ls/methods'
require 'pry/commands/ls/self_methods'
require 'pry/commands/ls/instance_vars'
require 'pry/commands/ls/local_names'
require 'pry/commands/ls/local_vars'
require 'pry/commands/ls/interrogatable'
require 'pry/commands/ls/ls_entity'
require 'pry/commands/ls/methods_helper'
require 'pry/commands/ls'

require 'pry/config/attributable'
require 'pry/config/value'
require 'pry/config/memoized_value'
require 'pry/config/lazy_value'
require 'pry/config'

require 'pry/input/simple_stdio'

require 'pry/pry_class'
require 'pry/pry_instance'
require 'pry/inspector'
require 'pry/pager'
require 'pry/indent'
require 'pry/object_path'
require 'pry/output'
require 'pry/input_lock'
require 'pry/repl'
require 'pry/code'
require 'pry/ring'
require 'pry/method'

require 'pry/wrapped_module'
require 'pry/wrapped_module/candidate'

require 'pry/slop'
require 'pry/cli'
require 'pry/core_extensions'
require 'pry/repl_file_loader'

require 'pry/code/loc'
require 'pry/code/code_range'
require 'pry/code/code_file'

require 'pry/method/weird_method_locator'
require 'pry/method/disowned'
require 'pry/method/patcher'

require 'pry/commands/amend_line'
require 'pry/commands/bang'
require 'pry/commands/bang_pry'

require 'pry/commands/cat'
require 'pry/commands/cat/abstract_formatter.rb'
require 'pry/commands/cat/input_expression_formatter.rb'
require 'pry/commands/cat/exception_formatter.rb'
require 'pry/commands/cat/file_formatter.rb'

require 'pry/commands/cd'
require 'pry/commands/change_inspector'
require 'pry/commands/change_prompt'
require 'pry/commands/clear_screen'
require 'pry/commands/code_collector'
require 'pry/commands/disable_pry'
require 'pry/commands/easter_eggs'

require 'pry/commands/edit'
require 'pry/commands/edit/exception_patcher'
require 'pry/commands/edit/file_and_line_locator'

require 'pry/commands/exit'
require 'pry/commands/exit_all'
require 'pry/commands/exit_program'
require 'pry/commands/find_method'
require 'pry/commands/fix_indent'
require 'pry/commands/help'
require 'pry/commands/hist'
require 'pry/commands/import_set'
require 'pry/commands/jump_to'
require 'pry/commands/list_inspectors'

require 'pry/commands/nesting'
require 'pry/commands/play'
require 'pry/commands/pry_backtrace'
require 'pry/commands/pry_version'
require 'pry/commands/raise_up'
require 'pry/commands/reload_code'
require 'pry/commands/reset'
require 'pry/commands/ri'
require 'pry/commands/save_file'
require 'pry/commands/shell_command'
require 'pry/commands/shell_mode'
require 'pry/commands/show_info'
require 'pry/commands/show_doc'
require 'pry/commands/show_input'
require 'pry/commands/show_source'
require 'pry/commands/stat'
require 'pry/commands/switch_to'
require 'pry/commands/toggle_color'

require 'pry/commands/watch_expression'
require 'pry/commands/watch_expression/expression.rb'

require 'pry/commands/whereami'
require 'pry/commands/wtf'
