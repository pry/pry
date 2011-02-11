Customizing Pry
---------------

Pry supports customization of the input, the output, the commands,
the hooks, the prompt, and the 'print' object (the "P" in REPL).

Global customization, which applies to all Pry sessions, is done
through invoking class accessors on the `Pry` class, the accessors
are:

* `Pry.input=`
* `Pry.output=`
* `Pry.commands=`
* `Pry.hooks=`
* `Pry.prompt=`
* `Pry.print=`

Local customization (applied to a single Pry session) is done by
passing config hash options to `Pry.start()` or to `Pry.new()`; also the
same accessors as described above for the `Pry` class exist for a
Pry instance so that customization can occur at runtime.

### Input

For input Pry accepts any object that implements the `readline` method. This
includes `IO` objects, `StringIO`, `Readline`, `File` and custom objects. Pry
initially defaults to using `Readline` for input.

#### Example: Setting global input

Setting Pry's global input causes all subsequent Pry instances to use
this input by default:

    Pry.input = StringIO.new("@x = 10\nexit")
    Object.pry

    Object.instance_variable_get(:@x) #=> 10

The above will execute the code in the `StringIO`
non-interactively. It gets all the input it needs from the `StringIO`
and then exits the Pry session. Note it is important to end the
session with 'exit' if you are running non-interactively or the Pry
session will hang as it loops indefinitely awaiting new input.

#### Example: Setting input for a specific session

The settings for a specific session override the global settings
(discussed above). There are two ways to set input for a specific pry session: At the
point the session is started, or within the session itself (at runtime):

##### At session start

    Pry.start(Object, :input => StringIO.new("@x = 10\nexit"))
    Object.instance_variable_get(:@x) #=> 10

##### At runtime

If you want to set the input object within the session itself you use
the special `_pry_` local variable which represents the Pry instance
managing the current session; inside the session we type:

    _pry_.input = StringIO.new("@x = 10\nexit")

Note we can also set the input object for the parent Pry session (if
the current session is nested) like so:

    _pry_.parent.input = StringIO.new("@x = 10\nexit")

### Output

For output Pry accepts any object that implements the `puts` method. This
includes `IO` objects, `StringIO`, `File` and custom objects. Pry initially
defaults to using `$stdout` for output.

#### Example: Setting global output

Setting Pry's global output causes all subsequent Pry instances to use
this output by default:

    Pry.output = StringIO.new

#### Example: Setting output for a specific session

As per Input, given above, we set the local output as follows:

##### At session start

    Pry.start(Object, :output => StringIO.new("@x = 10\nexit"))

##### At runtime
    
    _pry_.output = StringIO.new

### Commands

Pry commands are not methods; they are commands that are intercepted
and executed before a Ruby eval takes place. Pry comes with a default
command set (`Pry::Commands`), but these commands can be augmented or overriden by
user-specified ones.

The Pry command API is quite sophisticated supporting features such as:
command set inheritance, importing of specific commands from another
command set, deletion of commands, calling of commands within other
commands, and so on.

A valid Pry command object must inherit from
`Pry::CommandBase` (or one of its subclasses) and use the special command API:

#### Example: Defining a command object and setting it globally

    class MyCommands < Pry::CommandBase
      command "greet", "Greet the user." do |name, age|
        output.puts "Hello #{name.capitalize}, how does it feel being #{age}?"
      end
    end

    Pry.commands = MyCommands

Then inside a pry session:

    pry(main)> greet john 9
    Hello John, how does it feel being 9?
    => nil

#### Example: Using a command object in a specific session

As in the case of `input` and `output`:

##### At session start:

    Pry.start(self, :commands => MyCommands)

##### At runtime:

    _pry_.commands = MyCommands

#### The command API

The command API is defined by the `Pry::CommandBase` class (hence why
all commands must inherit from it or a subclass). The API works as follows:

##### `command` method

The `command` method defines a new command, its parameter is the
name of the command and an optional second parameter is a description of
the command.

The associated block defines the action to be performed. The number of
parameters in the block determine the number of parameters that will
be sent to the command (from the Pry prompt) when it is invoked. Note
that all parameters that are received will be strings; if a parameter
is not received it will be set to `nil`.

    command "hello" do |x, y, z|
      puts "hello there #{x}, #{y}, and #{z}!"
    end

Command aliases can also be defined - simply use an array of strings
for the command name - all these strings will be valid names for the
command.

    command ["ls", "dir"], "show a list of local vars" do
      output.puts target.eval("local_variables")
    end

##### `delete` method

The `delete` method deletes a command or a group of commands. It
can be useful when inheriting from another command set and you wish
to keep only a portion of the inherited commands.

    class MyCommands < Pry::Commands
      delete "show_method", "show_imethod"
    end

##### `import_from` method

The `import_from` method enables you to specifically select which
commands will be copied across from another command set, useful when
you only want a small number of commands and so inheriting and then
deleting would be inefficient. The first parameter to `import_from`
is the class to import from and the other paramters are the names of
the commands to import:

    class MyCommands < Pry::CommandBase
      import_from Pry::Commands, "ls", "status", "!"
    end

##### `run` method

The `run` command invokes one command from within another.
The first parameter is the name of the command to invoke
and the remainder of the parameters will be passed on to the command
being invoked:

    class MyCommands < Pry::Commands
      command "ls_with_hello" do
        output.puts "hello!"
        run "ls"
      end
    end

##### `alias_command` method

The `alias_command` method creates an alias of a command. The first
parameter is the name of the new command, the second parameter is the
name of the command to be aliased; an optional third parameter is the
description to use for the alias. If no description is provided then
the description of the original command is used.

    class MyCommands < Pry::Commands
      alias_command "help2", "help", "An alias of help"
    end

##### `desc` method

The `desc` method is used to give a command a new description. The
first parameter is the name of the command, the second parameter is
the description.

    class MyCommands < Pry::Commands
      desc "ls", "a new description"
    end

#### Utility methods for commands

All commands can access the special `output` and `target` methods. The
`output` method returns the `output` object for the active pry session.
Ensuring that your commands invoke `puts` on this rather than using
the top-level `puts` will ensure that all your session output goes to
the same place.

The `target` method returns the `Binding` object the Pry session is currently
active on - useful when your commands need to manipulate or examine
the state of the object. E.g, the "ls" command is implemented as follows

    command "ls" do
      output.puts target.eval("local_variables + instance_variables").inspect
    end

#### The opts hash

These are miscellaneous variables that may be useful to your commands:

* `opts[:val]` - The line of input that invoked the command.
* `opts[:eval_string]` - The cumulative lines of input for multi-line input.
* `opts[:nesting]` - Lowlevel session nesting information.
* `opts[:commands]` - Lowlevel data of all Pry commands.

(see commands.rb for examples of how some of these options are used)

#### The `help` command

The `Pry::CommandBase` class automatically defines a `help` command
for you. Typing `help` in a Pry session will show a list of commands
to the user followed by their descriptions. Passing a parameter to
`help` with the command name will just return the description of that
specific command. If a description is left out it will automatically
be given the description "No description.".

If the description is explicitly set to `""` then this command will
not be displayed in `help`.

### Hooks

Currently Pry supports just two hooks: `before_session` and
`after_session`. These hooks are invoked before a Pry session starts
and after a session ends respectively. The default hooks used are
stored in the `Pry::DEFAULT_HOOKS` and just output the text `"Beginning
Pry session for <obj>"` and `"Ending Pry session for <obj>"`.

#### Example: Setting global hooks

All subsequent Pry instances will use these hooks as default:

    Pry.hooks = {
      :before_session => proc { |out, obj| out.puts "Opened #{obj}" },
      :after_session => proc { |out, obj| out.puts "Closed #{obj}" }
    }

    5.pry

Inside the session:

    Opened 5
    pry(5)> exit
    Closed 5

Note that the `before_session` and `after_session` procs receive the
current session's output object and session receiver as parameters.

#### Example: Setting hooks for a specific session

Like all the other customization options, the global default (as
explained above) can be overriden for a specific session, either at
session start or during runtime.

##### At session start

    Pry.start(self, :hooks => { :before_session => proc { puts "hello world!" },
                                :after_session => proc { puts "goodbye world!" }
                              })

##### At runtime

    _pry_.hooks = { :before_session => proc { puts "puts "hello world!" } }

### Prompts

The Pry prompt is used by `Readline` and other input objects that
accept a prompt. Pry can accept two prompt-types for every prompt; the
'main prompt' and the 'wait prompt'. The main prompt is always used
for the first line of input; the wait prompt is used in multi-line
input to indicate that the current expression is incomplete and more lines of
input are required. The default Prompt used by Pry is stored in the
`Pry::DEFAULT_PROMPT` constant.

A valid Pry prompt is either a single `Proc` object or a two element
array of `Proc` objects. When an array is used the first element is
the 'main prompt' and the last element is the 'wait prompt'. When a
single `Proc` object is used it will be used for both the main prompt
and the wait prompt.

#### Example: Setting global prompt

The prompt `Proc` objects are passed the receiver of the Pry session
and the nesting level of that session as parameters (they can simply
ignore these if they do not need them).

    # Using one proc for both main and wait prompts
    Pry.prompt = proc { |obj, nest_level| "#{obj}:#{nest_level}> " }

    # Alternatively, provide two procs; one for main and one for wait
    Pry.prompt = [ proc { "ENTER INPUT> " }, proc { "MORE INPUT REQUIRED!* " }]

#### Example: Setting the prompt for a specific session

##### At session start

    Pry.start(self, :prompt => [proc { "ENTER INPUT> " },
                                proc { "MORE INPUT REQUIRED!* " }])

##### At runtime

    _pry_.prompt = [proc { "ENTER INPUT> " },
                    proc { "MORE INPUT REQUIRED!* " }]

### Print

The Print phase of Pry's READ-EVAL-PRINT-LOOP can be customized. The
default action is stored in the `Pry::DEFAULT_PRINT` constant and it
simply outputs the value of the current expression preceded by a `=>` (or the first
line of the backtrace if the value is an `Exception` object.)

The print object should be a `Proc` and the parameters passed to the
`Proc` are the output object for the current session and the 'value'
returned by the current expression.

#### Example: Setting global print object

Let's define a print object that displays the full backtrace of any
exception and precedes the output of a value by the text `"Output is: "`:

    Pry.print = proc do |output, value|
                  case value
                  when Exception
                    output.puts value.backtrace
                  else
                    output.puts "Output is: #{value}"
                  end
                end

#### Example: Setting the print object for a specific session

##### At session start

    Pry.start(self, :print => proc do |output, value|
                                case value
                                when Exception
                                  output.puts value.backtrace
                                else
                                  output.puts "Output is: #{value.inspect}"
                                end
                              end)

##### At runtime

    _pry_.print =  proc do |output, value|
                     case value
                     when Exception
                       output.puts value.backtrace
                     else
                       output.puts "Output is: #{value.inspect}"
                     end
                   end
    
[Back to front page of documentation](http://rdoc.info/github/banister/pry/master/file/README.markdown)
