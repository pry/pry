# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "pry"
  s.version = "0.9.8.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Mair (banisterfiend)"]
  s.date = "2012-03-06"
  s.description = "An IRB alternative and runtime developer console"
  s.email = "jrmair@gmail.com"
  s.executables = ["pry"]
  s.files = [".document", ".gemtest", ".gitignore", ".travis.yml", ".yardopts", "CHANGELOG", "CONTRIBUTORS", "Gemfile", "LICENSE", "README.markdown", "Rakefile", "TODO", "bin/pry", "examples/example_basic.rb", "examples/example_command_override.rb", "examples/example_commands.rb", "examples/example_hooks.rb", "examples/example_image_edit.rb", "examples/example_input.rb", "examples/example_input2.rb", "examples/example_output.rb", "examples/example_print.rb", "examples/example_prompt.rb", "examples/helper.rb", "lib/pry.rb", "lib/pry/cli.rb", "lib/pry/code.rb", "lib/pry/command.rb", "lib/pry/command_set.rb", "lib/pry/commands.rb", "lib/pry/completion.rb", "lib/pry/config.rb", "lib/pry/core_extensions.rb", "lib/pry/custom_completions.rb", "lib/pry/default_commands/cd.rb", "lib/pry/default_commands/commands.rb", "lib/pry/default_commands/context.rb", "lib/pry/default_commands/easter_eggs.rb", "lib/pry/default_commands/editing.rb", "lib/pry/default_commands/gems.rb", "lib/pry/default_commands/help.rb", "lib/pry/default_commands/hist.rb", "lib/pry/default_commands/input_and_output.rb", "lib/pry/default_commands/introspection.rb", "lib/pry/default_commands/ls.rb", "lib/pry/default_commands/misc.rb", "lib/pry/default_commands/navigating_pry.rb", "lib/pry/extended_commands/experimental.rb", "lib/pry/helpers.rb", "lib/pry/helpers/base_helpers.rb", "lib/pry/helpers/command_helpers.rb", "lib/pry/helpers/options_helpers.rb", "lib/pry/helpers/text.rb", "lib/pry/history.rb", "lib/pry/history_array.rb", "lib/pry/hooks.rb", "lib/pry/indent.rb", "lib/pry/method.rb", "lib/pry/plugins.rb", "lib/pry/pry_class.rb", "lib/pry/pry_instance.rb", "lib/pry/rbx_method.rb", "lib/pry/rbx_path.rb", "lib/pry/version.rb", "lib/pry/wrapped_module.rb", "man/pry.1", "man/pry.1.html", "man/pry.1.ronn", "pry.gemspec", "test/helper.rb", "test/test_cli.rb", "test/test_code.rb", "test/test_command.rb", "test/test_command_helpers.rb", "test/test_command_integration.rb", "test/test_command_set.rb", "test/test_completion.rb", "test/test_default_commands/test_context.rb", "test/test_default_commands/test_documentation.rb", "test/test_default_commands/test_gems.rb", "test/test_default_commands/test_help.rb", "test/test_default_commands/test_input.rb", "test/test_default_commands/test_introspection.rb", "test/test_default_commands/test_ls.rb", "test/test_default_commands/test_shell.rb", "test/test_exception_whitelist.rb", "test/test_history_array.rb", "test/test_hooks.rb", "test/test_indent.rb", "test/test_input_stack.rb", "test/test_method.rb", "test/test_pry.rb", "test/test_pry_defaults.rb", "test/test_pry_history.rb", "test/test_pry_output.rb", "test/test_sticky_locals.rb", "test/test_syntax_checking.rb", "test/test_wrapped_module.rb", "test/testrc", "test/testrcbad", "wiki/Customizing-pry.md", "wiki/Home.md"]
  s.homepage = "http://pry.github.com"
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.16"
  s.summary = "An IRB alternative and runtime developer console"
  s.test_files = ["test/helper.rb", "test/test_cli.rb", "test/test_code.rb", "test/test_command.rb", "test/test_command_helpers.rb", "test/test_command_integration.rb", "test/test_command_set.rb", "test/test_completion.rb", "test/test_default_commands/test_context.rb", "test/test_default_commands/test_documentation.rb", "test/test_default_commands/test_gems.rb", "test/test_default_commands/test_help.rb", "test/test_default_commands/test_input.rb", "test/test_default_commands/test_introspection.rb", "test/test_default_commands/test_ls.rb", "test/test_default_commands/test_shell.rb", "test/test_exception_whitelist.rb", "test/test_history_array.rb", "test/test_hooks.rb", "test/test_indent.rb", "test/test_input_stack.rb", "test/test_method.rb", "test/test_pry.rb", "test/test_pry_defaults.rb", "test/test_pry_history.rb", "test/test_pry_output.rb", "test/test_sticky_locals.rb", "test/test_syntax_checking.rb", "test/test_wrapped_module.rb", "test/testrc", "test/testrcbad"]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<coderay>, ["~> 1.0.5"])
      s.add_runtime_dependency(%q<slop>, ["< 3", ">= 2.4.4"])
      s.add_runtime_dependency(%q<method_source>, ["~> 0.7.1"])
      s.add_development_dependency(%q<bacon>, ["~> 1.1"])
      s.add_development_dependency(%q<open4>, ["~> 1.3"])
      s.add_development_dependency(%q<rake>, ["~> 0.9"])
    else
      s.add_dependency(%q<coderay>, ["~> 1.0.5"])
      s.add_dependency(%q<slop>, ["< 3", ">= 2.4.4"])
      s.add_dependency(%q<method_source>, ["~> 0.7.1"])
      s.add_dependency(%q<bacon>, ["~> 1.1"])
      s.add_dependency(%q<open4>, ["~> 1.3"])
      s.add_dependency(%q<rake>, ["~> 0.9"])
    end
  else
    s.add_dependency(%q<coderay>, ["~> 1.0.5"])
    s.add_dependency(%q<slop>, ["< 3", ">= 2.4.4"])
    s.add_dependency(%q<method_source>, ["~> 0.7.1"])
    s.add_dependency(%q<bacon>, ["~> 1.1"])
    s.add_dependency(%q<open4>, ["~> 1.3"])
    s.add_dependency(%q<rake>, ["~> 0.9"])
  end
end
