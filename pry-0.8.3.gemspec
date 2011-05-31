# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{pry}
  s.version = "0.8.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Mair (banisterfiend)"]
  s.date = %q{2011-05-31}
  s.default_executable = %q{pry}
  s.description = %q{attach an irb-like session to any object at runtime}
  s.email = %q{jrmair@gmail.com}
  s.executables = ["pry"]
  s.files = [".document", ".gemtest", ".gitignore", ".yardopts", "CHANGELOG", "LICENSE", "README.markdown", "Rakefile", "TODO", "bin/pry", "examples/example_basic.rb", "examples/example_command_override.rb", "examples/example_commands.rb", "examples/example_hooks.rb", "examples/example_image_edit.rb", "examples/example_input.rb", "examples/example_input2.rb", "examples/example_output.rb", "examples/example_print.rb", "examples/example_prompt.rb", "lib/pry.rb", "lib/pry/command_context.rb", "lib/pry/command_processor.rb", "lib/pry/command_set.rb", "lib/pry/commands.rb", "lib/pry/completion.rb", "lib/pry/core_extensions.rb", "lib/pry/custom_completions.rb", "lib/pry/helpers.rb", "lib/pry/helpers/base_helpers.rb", "lib/pry/helpers/command_helpers.rb", "lib/pry/hooks.rb", "lib/pry/print.rb", "lib/pry/prompts.rb", "lib/pry/pry_class.rb", "lib/pry/pry_instance.rb", "lib/pry/version.rb", "test/test.rb", "test/test_helper.rb", "test/testrc", "wiki/Customizing-pry.md", "wiki/Home.md"]
  s.homepage = %q{http://banisterfiend.wordpress.com}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.6.2}
  s.summary = %q{attach an irb-like session to any object at runtime}
  s.test_files = ["test/test.rb", "test/test_helper.rb", "test/testrc"]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<ruby_parser>, [">= 2.0.5"])
      s.add_runtime_dependency(%q<coderay>, [">= 0.9.8"])
      s.add_runtime_dependency(%q<slop>, [">= 1.5.5"])
      s.add_runtime_dependency(%q<method_source>, [">= 0.4.0"])
      s.add_development_dependency(%q<bacon>, [">= 1.1.0"])
    else
      s.add_dependency(%q<ruby_parser>, [">= 2.0.5"])
      s.add_dependency(%q<coderay>, [">= 0.9.8"])
      s.add_dependency(%q<slop>, [">= 1.5.5"])
      s.add_dependency(%q<method_source>, [">= 0.4.0"])
      s.add_dependency(%q<bacon>, [">= 1.1.0"])
    end
  else
    s.add_dependency(%q<ruby_parser>, [">= 2.0.5"])
    s.add_dependency(%q<coderay>, [">= 0.9.8"])
    s.add_dependency(%q<slop>, [">= 1.5.5"])
    s.add_dependency(%q<method_source>, [">= 0.4.0"])
    s.add_dependency(%q<bacon>, [">= 1.1.0"])
  end
end
