# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "pry"
  s.version = "0.9.11"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Mair (banisterfiend)", "Conrad Irwin", "Ryan Fitzgerald"]
  s.date = "2012-11-29"
  s.description = "An IRB alternative and runtime developer console"
  s.email = ["jrmair@gmail.com", "conrad.irwin@gmail.com", "rwfitzge@gmail.com"]
  s.executables = ["pry"]
  s.files = [".document", ".gemtest", ".gitignore", ".travis.yml", ".yardopts", "CHANGELOG", "CONTRIBUTORS", "Gemfile", "Guardfile", "LICENSE", "README.markdown", "Rakefile", "TODO", "bin/pry", "examples/example_basic.rb", "examples/example_command_override.rb", "examples/example_commands.rb", "examples/example_hooks.rb", "examples/example_image_edit.rb", "examples/example_input.rb", "examples/example_input2.rb", "examples/example_output.rb", "examples/example_print.rb", "examples/example_prompt.rb", "examples/helper.rb", "lib/pry.rb", "lib/pry/cli.rb", "lib/pry/code.rb", "lib/pry/command.rb", "lib/pry/command_set.rb", "lib/pry/commands.rb", "lib/pry/commands/amend_line.rb", "lib/pry/commands/bang.rb", "lib/pry/commands/bang_pry.rb", "lib/pry/commands/cat.rb", "lib/pry/commands/cd.rb", "lib/pry/commands/disable_pry.rb", "lib/pry/commands/easter_eggs.rb", "lib/pry/commands/edit.rb", "lib/pry/commands/edit_method.rb", "lib/pry/commands/exit.rb", "lib/pry/commands/exit_all.rb", "lib/pry/commands/exit_program.rb", "lib/pry/commands/find_method.rb", "lib/pry/commands/gem_cd.rb", "lib/pry/commands/gem_install.rb", "lib/pry/commands/gem_list.rb", "lib/pry/commands/gem_open.rb", "lib/pry/commands/gist.rb", "lib/pry/commands/help.rb", "lib/pry/commands/hist.rb", "lib/pry/commands/import_set.rb", "lib/pry/commands/install_command.rb", "lib/pry/commands/jump_to.rb", "lib/pry/commands/ls.rb", "lib/pry/commands/nesting.rb", "lib/pry/commands/play.rb", "lib/pry/commands/pry_backtrace.rb", "lib/pry/commands/pry_version.rb", "lib/pry/commands/raise_up.rb", "lib/pry/commands/reload_method.rb", "lib/pry/commands/reset.rb", "lib/pry/commands/ri.rb", "lib/pry/commands/save_file.rb", "lib/pry/commands/shell_command.rb", "lib/pry/commands/shell_mode.rb", "lib/pry/commands/show_command.rb", "lib/pry/commands/show_doc.rb", "lib/pry/commands/show_input.rb", "lib/pry/commands/show_source.rb", "lib/pry/commands/simple_prompt.rb", "lib/pry/commands/stat.rb", "lib/pry/commands/switch_to.rb", "lib/pry/commands/toggle_color.rb", "lib/pry/commands/whereami.rb", "lib/pry/commands/wtf.rb", "lib/pry/completion.rb", "lib/pry/config.rb", "lib/pry/core_extensions.rb", "lib/pry/custom_completions.rb", "lib/pry/helpers.rb", "lib/pry/helpers/base_helpers.rb", "lib/pry/helpers/command_helpers.rb", "lib/pry/helpers/documentation_helpers.rb", "lib/pry/helpers/module_introspection_helpers.rb", "lib/pry/helpers/options_helpers.rb", "lib/pry/helpers/text.rb", "lib/pry/history.rb", "lib/pry/history_array.rb", "lib/pry/hooks.rb", "lib/pry/indent.rb", "lib/pry/method.rb", "lib/pry/module_candidate.rb", "lib/pry/pager.rb", "lib/pry/plugins.rb", "lib/pry/pry_class.rb", "lib/pry/pry_instance.rb", "lib/pry/rbx_method.rb", "lib/pry/rbx_path.rb", "lib/pry/repl_file_loader.rb", "lib/pry/terminal_info.rb", "lib/pry/test/bacon_helper.rb", "lib/pry/test/helper.rb", "lib/pry/version.rb", "lib/pry/wrapped_module.rb", "man/pry.1", "man/pry.1.html", "man/pry.1.ronn", "notes.yml", "pry.gemspec", "spec/candidate_helper1.rb", "spec/candidate_helper2.rb", "spec/cli_spec.rb", "spec/code_spec.rb", "spec/command_helpers_spec.rb", "spec/command_integration_spec.rb", "spec/command_set_spec.rb", "spec/command_spec.rb", "spec/commands/amend_line_spec.rb", "spec/commands/bang_spec.rb", "spec/commands/cat_spec.rb", "spec/commands/cd_spec.rb", "spec/commands/disable_pry_spec.rb", "spec/commands/edit_method_spec.rb", "spec/commands/edit_spec.rb", "spec/commands/exit_all_spec.rb", "spec/commands/exit_program_spec.rb", "spec/commands/exit_spec.rb", "spec/commands/find_method_spec.rb", "spec/commands/gem_list_spec.rb", "spec/commands/help_spec.rb", "spec/commands/hist_spec.rb", "spec/commands/jump_to_spec.rb", "spec/commands/ls_spec.rb", "spec/commands/play_spec.rb", "spec/commands/raise_up_spec.rb", "spec/commands/save_file_spec.rb", "spec/commands/show_doc_spec.rb", "spec/commands/show_input_spec.rb", "spec/commands/show_source_spec.rb", "spec/commands/whereami_spec.rb", "spec/completion_spec.rb", "spec/control_d_handler_spec.rb", "spec/example_nesting.rb", "spec/exception_whitelist_spec.rb", "spec/fixtures/example.erb", "spec/history_array_spec.rb", "spec/hooks_spec.rb", "spec/indent_spec.rb", "spec/input_stack_spec.rb", "spec/method_spec.rb", "spec/prompt_spec.rb", "spec/pry_defaults_spec.rb", "spec/pry_history_spec.rb", "spec/pry_output_spec.rb", "spec/pry_spec.rb", "spec/sticky_locals_spec.rb", "spec/syntax_checking_spec.rb", "spec/testrc", "spec/testrcbad", "spec/wrapped_module_spec.rb", "wiki/Customizing-pry.md", "wiki/Home.md"]
  s.homepage = "http://pry.github.com"
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.23"
  s.summary = "An IRB alternative and runtime developer console"
  s.test_files = ["spec/candidate_helper1.rb", "spec/candidate_helper2.rb", "spec/cli_spec.rb", "spec/code_spec.rb", "spec/command_helpers_spec.rb", "spec/command_integration_spec.rb", "spec/command_set_spec.rb", "spec/command_spec.rb", "spec/commands/amend_line_spec.rb", "spec/commands/bang_spec.rb", "spec/commands/cat_spec.rb", "spec/commands/cd_spec.rb", "spec/commands/disable_pry_spec.rb", "spec/commands/edit_method_spec.rb", "spec/commands/edit_spec.rb", "spec/commands/exit_all_spec.rb", "spec/commands/exit_program_spec.rb", "spec/commands/exit_spec.rb", "spec/commands/find_method_spec.rb", "spec/commands/gem_list_spec.rb", "spec/commands/help_spec.rb", "spec/commands/hist_spec.rb", "spec/commands/jump_to_spec.rb", "spec/commands/ls_spec.rb", "spec/commands/play_spec.rb", "spec/commands/raise_up_spec.rb", "spec/commands/save_file_spec.rb", "spec/commands/show_doc_spec.rb", "spec/commands/show_input_spec.rb", "spec/commands/show_source_spec.rb", "spec/commands/whereami_spec.rb", "spec/completion_spec.rb", "spec/control_d_handler_spec.rb", "spec/example_nesting.rb", "spec/exception_whitelist_spec.rb", "spec/fixtures/example.erb", "spec/history_array_spec.rb", "spec/hooks_spec.rb", "spec/indent_spec.rb", "spec/input_stack_spec.rb", "spec/method_spec.rb", "spec/prompt_spec.rb", "spec/pry_defaults_spec.rb", "spec/pry_history_spec.rb", "spec/pry_output_spec.rb", "spec/pry_spec.rb", "spec/sticky_locals_spec.rb", "spec/syntax_checking_spec.rb", "spec/testrc", "spec/testrcbad", "spec/wrapped_module_spec.rb"]

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
