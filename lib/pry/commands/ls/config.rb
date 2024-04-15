# frozen_string_literal: true

class Pry
  class Command
    class Ls < Pry::ClassCommand
      class Config
        attr_accessor :heading_color,
                      :public_method_color,
                      :private_method_color,
                      :protected_method_color,
                      :method_missing_color,
                      :local_var_color,
                      :pry_var_color,            # e.g. _, pry_instance, _file_
                      :instance_var_color,       # e.g. @foo
                      :class_var_color,          # e.g. @@foo
                      :global_var_color,         # e.g. $CODERAY_DEBUG, $foo
                      :builtin_global_color,     # e.g. $stdin, $-w, $PID
                      :pseudo_global_color,      # e.g. $~, $1..$9, $LAST_MATCH_INFO
                      :constant_color,           # e.g. VERSION, ARGF
                      :class_constant_color,     # e.g. Object, Kernel
                      :exception_constant_color, # e.g. Exception, RuntimeError
                      :unloaded_constant_color,  # Constant that is still in .autoload?
                      :separator,
                      :ceiling

        def self.default
          config = new
          config.heading_color = :bright_blue
          config.public_method_color = :default
          config.private_method_color = :blue
          config.protected_method_color = :blue
          config.method_missing_color = :bright_red
          config.local_var_color = :yellow
          config.pry_var_color = :default
          config.instance_var_color = :blue
          config.class_var_color = :bright_blue
          config.global_var_color = :default
          config.builtin_global_color = :cyan
          config.pseudo_global_color = :cyan
          config.constant_color = :default
          config.class_constant_color = :blue
          config.exception_constant_color = :magenta
          config.unloaded_constant_color = :yellow
          config.separator = "  "
          config.ceiling = [Object, Module, Class]
          config
        end
      end
    end
  end
end
