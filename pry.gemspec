# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "pry"
  s.version = "0.9.10"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Mair (banisterfiend)", "Conrad Irwin", "Ryan Fitzgerald"]
  s.date = "2012-11-14"
  s.description = "An IRB alternative and runtime developer console"
  s.email = ["jrmair@gmail.com", "conrad.irwin@gmail.com", "rwfitzge@gmail.com"]
  s.executables = ["pry"]
  s.files = [".document", ".gemtest", ".gitignore", ".travis.yml", ".yardopts", "CHANGELOG", "CONTRIBUTORS", "Gemfile", "Guardfile", "LICENSE", "README.markdown", "Rakefile", "TODO", "bin/pry", "examples/example_basic.rb", "examples/example_command_override.rb", "examples/example_commands.rb", "examples/example_hooks.rb", "examples/example_image_edit.rb", "examples/example_input.rb", "examples/example_input2.rb", "examples/example_output.rb", "examples/example_print.rb", "examples/example_prompt.rb", "examples/helper.rb", "lib/pry.rb", "lib/pry/cli.rb", "lib/pry/code.rb", "lib/pry/command.rb", "lib/pry/command_set.rb", "lib/pry/commands.rb", "lib/pry/commands/amend_line.rb", "lib/pry/commands/bang.rb", "lib/pry/commands/bang_pry.rb", "lib/pry/commands/cat.rb", "lib/pry/commands/cd.rb", "lib/pry/commands/disable_pry.rb", "lib/pry/commands/easter_eggs.rb", "lib/pry/commands/edit.rb", "lib/pry/commands/edit_method.rb", "lib/pry/commands/exit.rb", "lib/pry/commands/exit_all.rb", "lib/pry/commands/exit_program.rb", "lib/pry/commands/find_method.rb", "lib/pry/commands/gem_cd.rb", "lib/pry/commands/gem_install.rb", "lib/pry/commands/gem_list.rb", "lib/pry/commands/gem_open.rb", "lib/pry/commands/gist.rb", "lib/pry/commands/help.rb", "lib/pry/commands/hist.rb", "lib/pry/commands/import_set.rb", "lib/pry/commands/install_command.rb", "lib/pry/commands/jump_to.rb", "lib/pry/commands/ls.rb", "lib/pry/commands/nesting.rb", "lib/pry/commands/play.rb", "lib/pry/commands/pry_backtrace.rb", "lib/pry/commands/pry_version.rb", "lib/pry/commands/raise_up.rb", "lib/pry/commands/reload_method.rb", "lib/pry/commands/reset.rb", "lib/pry/commands/ri.rb", "lib/pry/commands/save_file.rb", "lib/pry/commands/shell_command.rb", "lib/pry/commands/shell_mode.rb", "lib/pry/commands/show_command.rb", "lib/pry/commands/show_doc.rb", "lib/pry/commands/show_input.rb", "lib/pry/commands/show_source.rb", "lib/pry/commands/simple_prompt.rb", "lib/pry/commands/stat.rb", "lib/pry/commands/switch_to.rb", "lib/pry/commands/toggle_color.rb", "lib/pry/commands/whereami.rb", "lib/pry/commands/wtf.rb", "lib/pry/completion.rb", "lib/pry/config.rb", "lib/pry/core_extensions.rb", "lib/pry/custom_completions.rb", "lib/pry/helpers.rb", "lib/pry/helpers/base_helpers.rb", "lib/pry/helpers/command_helpers.rb", "lib/pry/helpers/documentation_helpers.rb", "lib/pry/helpers/module_introspection_helpers.rb", "lib/pry/helpers/options_helpers.rb", "lib/pry/helpers/text.rb", "lib/pry/history.rb", "lib/pry/history_array.rb", "lib/pry/hooks.rb", "lib/pry/indent.rb", "lib/pry/method.rb", "lib/pry/module_candidate.rb", "lib/pry/pager.rb", "lib/pry/plugins.rb", "lib/pry/pry_class.rb", "lib/pry/pry_instance.rb", "lib/pry/rbx_method.rb", "lib/pry/rbx_path.rb", "lib/pry/repl_file_loader.rb", "lib/pry/version.rb", "lib/pry/wrapped_module.rb", "man/pry.1", "man/pry.1.html", "man/pry.1.ronn", "pry.gemspec", "test/candidate_helper1.rb", "test/candidate_helper2.rb", "test/example_nesting.rb", "test/helper.rb", "test/test_cli.rb", "test/test_code.rb", "test/test_command.rb", "test/test_command_helpers.rb", "test/test_command_integration.rb", "test/test_command_set.rb", "test/test_commands/example.erb", "test/test_commands/test_amend_line.rb", "test/test_commands/test_bang.rb", "test/test_commands/test_cat.rb", "test/test_commands/test_cd.rb", "test/test_commands/test_disable_pry.rb", "test/test_commands/test_edit.rb", "test/test_commands/test_edit_method.rb", "test/test_commands/test_exit.rb", "test/test_commands/test_exit_all.rb", "test/test_commands/test_exit_program.rb", "test/test_commands/test_find_method.rb", "test/test_commands/test_gem_list.rb", "test/test_commands/test_help.rb", "test/test_commands/test_hist.rb", "test/test_commands/test_jump_to.rb", "test/test_commands/test_ls.rb", "test/test_commands/test_play.rb", "test/test_commands/test_raise_up.rb", "test/test_commands/test_save_file.rb", "test/test_commands/test_show_doc.rb", "test/test_commands/test_show_input.rb", "test/test_commands/test_show_source.rb", "test/test_commands/test_whereami.rb", "test/test_completion.rb", "test/test_control_d_handler.rb", "test/test_exception_whitelist.rb", "test/test_history_array.rb", "test/test_hooks.rb", "test/test_indent.rb", "test/test_input_stack.rb", "test/test_method.rb", "test/test_prompt.rb", "test/test_pry.rb", "test/test_pry_defaults.rb", "test/test_pry_history.rb", "test/test_pry_output.rb", "test/test_sticky_locals.rb", "test/test_syntax_checking.rb", "test/test_wrapped_module.rb", "test/testrc", "test/testrcbad", "wiki/Customizing-pry.md", "wiki/Home.md"]
  s.homepage = "http://pry.github.com"
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.24"
  s.summary = "An IRB alternative and runtime developer console"
  s.test_files = ["test/candidate_helper1.rb", "test/candidate_helper2.rb", "test/example_nesting.rb", "test/helper.rb", "test/test_cli.rb", "test/test_code.rb", "test/test_command.rb", "test/test_command_helpers.rb", "test/test_command_integration.rb", "test/test_command_set.rb", "test/test_commands/example.erb", "test/test_commands/test_amend_line.rb", "test/test_commands/test_bang.rb", "test/test_commands/test_cat.rb", "test/test_commands/test_cd.rb", "test/test_commands/test_disable_pry.rb", "test/test_commands/test_edit.rb", "test/test_commands/test_edit_method.rb", "test/test_commands/test_exit.rb", "test/test_commands/test_exit_all.rb", "test/test_commands/test_exit_program.rb", "test/test_commands/test_find_method.rb", "test/test_commands/test_gem_list.rb", "test/test_commands/test_help.rb", "test/test_commands/test_hist.rb", "test/test_commands/test_jump_to.rb", "test/test_commands/test_ls.rb", "test/test_commands/test_play.rb", "test/test_commands/test_raise_up.rb", "test/test_commands/test_save_file.rb", "test/test_commands/test_show_doc.rb", "test/test_commands/test_show_input.rb", "test/test_commands/test_show_source.rb", "test/test_commands/test_whereami.rb", "test/test_completion.rb", "test/test_control_d_handler.rb", "test/test_exception_whitelist.rb", "test/test_history_array.rb", "test/test_hooks.rb", "test/test_indent.rb", "test/test_input_stack.rb", "test/test_method.rb", "test/test_prompt.rb", "test/test_pry.rb", "test/test_pry_defaults.rb", "test/test_pry_history.rb", "test/test_pry_output.rb", "test/test_sticky_locals.rb", "test/test_syntax_checking.rb", "test/test_wrapped_module.rb", "test/testrc", "test/testrcbad"]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<coderay>, ["~> 1.0.5"])
      s.add_runtime_dependency(%q<slop>, ["~> 3.3.1"])
      s.add_runtime_dependency(%q<method_source>, ["~> 0.8"])
      s.add_development_dependency(%q<bacon>, ["~> 1.1"])
      s.add_development_dependency(%q<open4>, ["~> 1.3"])
      s.add_development_dependency(%q<rake>, ["~> 0.9"])
      s.add_development_dependency(%q<guard>, ["~> 1.3.2"])
      s.add_development_dependency(%q<bond>, ["~> 0.4.2"])
    else
      s.add_dependency(%q<coderay>, ["~> 1.0.5"])
      s.add_dependency(%q<slop>, ["~> 3.3.1"])
      s.add_dependency(%q<method_source>, ["~> 0.8"])
      s.add_dependency(%q<bacon>, ["~> 1.1"])
      s.add_dependency(%q<open4>, ["~> 1.3"])
      s.add_dependency(%q<rake>, ["~> 0.9"])
      s.add_dependency(%q<guard>, ["~> 1.3.2"])
      s.add_dependency(%q<bond>, ["~> 0.4.2"])
    end
  else
    s.add_dependency(%q<coderay>, ["~> 1.0.5"])
    s.add_dependency(%q<slop>, ["~> 3.3.1"])
    s.add_dependency(%q<method_source>, ["~> 0.8"])
    s.add_dependency(%q<bacon>, ["~> 1.1"])
    s.add_dependency(%q<open4>, ["~> 1.3"])
    s.add_dependency(%q<rake>, ["~> 0.9"])
    s.add_dependency(%q<guard>, ["~> 1.3.2"])
    s.add_dependency(%q<bond>, ["~> 0.4.2"])
  end
end
