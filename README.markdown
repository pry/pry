Pry
=============

(C) John Mair (banisterfiend) 2011

_attach an irb-like session to any object at runtime_

Pry is a simple Ruby REPL (Read-Eval-Print-Loop) that specializes in the interactive
manipulation of objects during the running of a program.

In some sense it is the opposite of IRB in that you bring a REPL
session to your code (with Pry) instead of bringing your code to a
REPL session (as with IRB).

It is not based on the IRB codebase, and implements some unique REPL
commands such as `show-method`, `show-doc`, `ls` and `cd` (type `help`
to get a full list).

Pry is also fairly flexible and allows significant user
[customization](http://rdoc.info/github/banister/pry/master/file/wiki/Customizing-pry.md). It
is trivial to set it to read from any object that has a `readline` method and write to any object that has a
`puts` method - many other aspects of Pry are also configurable making
it a good choice for implementing custom shells.

Pry now comes with an executable so it can be invoked at the command line.
Just enter `pry` to start. A `.pryrc` file in the user's home directory will
be loaded if it exists. Type `pry --help` at the command line for more information.

* Install the [gem](https://rubygems.org/gems/pry): `gem install pry`
* Read the [documentation](http://rdoc.info/github/banister/pry/master/file/README.markdown)
* See the [source code](http://github.com/banister/pry)

Pry also has `rubygems-test` support; to participate, first install
Pry, then:

1. Install rubygems-test: `gem install rubygems-test`
2. Run the test: `gem test pry`
3. Finally choose 'Yes' to upload the results. 

Example: Interacting with an object at runtime
---------------------------------------

With the `Object#pry` method we can pry (open an irb-like session) on
an object. In the example below we open a Pry session for the `Test` class and execute a method and add
an instance variable. The current thread is halted for the duration of the session.

    require 'pry'

    class Test
      def self.hello() "hello world" end
    end

    Test.pry

    # Pry session begins on stdin
    Beginning Pry session for Test
    pry(Test)> self
    => Test
    pry(Test)> hello
    => "hello world"
    pry(Test)> @y = 20
    => 20
    pry(Test)> exit
    Ending Pry session for Test

    # program resumes here

If we now inspect the `Test` object we can see our changes have had
effect:

    Test.instance_variable_get(:@y) #=> 20

### Alternative Syntax

You can also use the `Pry.start(obj)` or `pry(obj)` syntax to start a pry session on
`obj`. e.g

    Pry.start(5)
    Beginning Pry session for 5
    pry(5)>

OR

    pry(6)
    beginning Pry session for 6
    pry(6)>

Example: Pry sessions can nest
-----------------------------------------------

Here we will begin Pry at top-level, then pry on a class and then on
an instance variable inside that class:

    # Pry.start() without parameters begins a Pry session on top-level (main)
    Pry.start
    Beginning Pry session for main
    pry(main)> class Hello
    pry(main)*   @x = 20
    pry(main)* end
    => 20
    pry(main)> cd Hello
    Beginning Pry session for Hello
    pry(Hello):1> instance_variables
    => [:@x]
    pry(Hello):1> cd @x
    Beginning Pry session for 20
    pry(20:2)> self + 10
    => 30
    pry(20:2)> cd ..
    Ending Pry session for 20
    pry(Hello):1> cd ..
    Ending Pry session for Hello
    pry(main)> cd ..
    Ending Pry session for main

The number after the `:` in the pry prompt indicates the nesting
level. To display more information about nesting, use the `nesting`
command. E.g

    pry("friend":3)> nesting
    Nesting status:
    0. main (Pry top level)
    1. Hello
    2. 100
    3. "friend"
    => nil

We can then jump back to any of the previous nesting levels by using
the `jump-to` command:

    pry("friend":3)> jump-to 1
    Ending Pry session for "friend"
    Ending Pry session for 100
    => 100
    pry(Hello):1>

If we just want to go back one level of nesting we can of course
use the `quit` or `exit` or `back` commands.

To break out of all levels of Pry nesting and return immediately to the
calling process use `exit-all`:

    pry("friend":3)> exit-all
    Ending Pry session for "friend"
    Ending Pry session for 100
    Ending Pry session for Hello
    Ending Pry session for main
    => main

    # program resumes here

Features and limitations
------------------------

Pry is an irb-like clone with an emphasis on interactively examining
and manipulating objects during the running of a program.

Its primary utility is probably in debugging, though it may have other
uses (such as implementing a quake-like console for games, for example). Here is a
list of Pry's features along with some of its limitations given at the
end.

###Features:

* Pry can be invoked at any time and on any object in the running program.
* Pry sessions can nest arbitrarily deeply -- to go back one level of nesting type 'exit' or 'quit' or 'back'
* Use `_` to recover last result.
* Use `_pry_` to reference the Pry instance managing the current session.
* Pry supports tab completion.
* Pry has multi-line support built in.
* Use `^d` (control-d) to quickly break out of a session.
* Pry has special commands not found in many other Ruby REPLs: `show-method`, `show-doc`
`jump-to`, `ls`, `cd`, `cat`
* Pry gives good control over nested sessions (important when exploring complicated runtime state)
* Pry is not based on the IRB codebase.
* Pry allows significant customizability.
* Pry uses the [method_source](https://github.com/banister/method_source) gem; so
this functionality is available to a Pry session.
* Pry uses [RubyParser](https://github.com/seattlerb/ruby_parser) to
validate expressions in 1.8, and [Ripper](http://rdoc.info/docs/ruby-core/1.9.2/Ripper) for 1.9.
* Pry implements all the methods in the REPL chain separately: `Pry#r`
for reading; `Pry#re` for eval; `Pry#rep` for printing; and `Pry#repl`
for the loop (`Pry.start` simply wraps `Pry.new.repl`). You can
invoke any of these methods directly depending on exactly what aspect of the functionality you need.

###Limitations:

* Some Pry commands (e.g `show-command`) do not work in Ruby 1.8.
* 1.9 support requires `Ripper` - some implementations may not support this.

Commands
-----------

### The Pry API:

* `Pry.start()` Starts a Read-Eval-Print-Loop on the object it
receives as a parameter. In the case of no parameter it operates on
top-level (main). It can receive any object or a `Binding`
object as parameter. `Pry.start()` is implemented as `Pry.new.repl()`
* `obj.pry` and `pry(obj)` may also be used as alternative syntax to
`Pry.start(obj)`.

  However there are some differences. `obj.pry` opens
a Pry session on the receiver whereas `Pry.start` (with no parameter)
will start a Pry session on top-level. The other form of the `pry`
method: `pry(obj)` will also start a Pry session on its parameter.

  The `pry` method invoked by itself, with no explict receiver and no
parameter will start a Pry session on the implied receiver. It is
perhaps more useful to invoke it in this form `pry(binding)` or
`binding.pry` so as to get access to locals in the current context.

  Another difference is that `Pry.start()` accepts a second parameter
that is a hash of configuration options (discussed further, below).

* If, for some reason you do not want to 'loop' then use `Pry.new.rep()`; it
only performs the Read-Eval-Print section of the REPL - it ends the
session after just one line of input. It takes the same parameters as
`Pry#repl()`
* Likewise `Pry#re()` only performs the Read-Eval section of the REPL,
it returns the result of the evaluation or an Exception object in
case of error. It also takes the same parameters as `Pry#repl()`
* Similarly `Pry#r()` only performs the Read section of the REPL, only
returning the Ruby expression (as a string). It takes the same parameters as all the others.
* `Pry.run_command COMMAND` enables you to invoke Pry commands outside
of a session, e.g `Pry.run_command "ls -m", :context => MyObject`. See
docs for more info.

### Session commands

Pry supports a few commands inside the session itself. These commands are
not methods and must start at the beginning of a line, with no
whitespace in between.

If you want to access a method of the same name, prefix the invocation by whitespace.

* Typing `!` on a line by itself will clear the input buffer - useful for
  getting you out of a situation where the parsing process
  goes wrong and you get stuck in an endless read loop.
* `status` shows status information about the current session.
* `version` Show Pry version information
* `help` shows the list of session commands with brief explanations.
* `exit` or `quit` or `back` or `^d` (control-d) will end the current Pry session and go
  back to the calling process or back one level of nesting (if there
  are nested sessions).
* `ls [OPTIONS] [VAR]` returns a list of local variables, instance variables, and
  methods, etc. Highly flexible. See `ls --help` for more info.
* `cat VAR` Calls `inspect` on `VAR`
* `cd VAR` Starts a `Pry` session on the variable VAR. E.g `cd @x`
(use `cd ..` to go back).
* `show-method [OPTIONS] METH` Displays the sourcecode for the method
  `METH`. e.g `show-method hello`. See `show-method --help` for more info.
* `show-doc [OPTIONS] METH` Displays comments for `METH`. See `show-doc
  --help` for more info.
* `show-command COMMAND` Displays the sourcecode for the given Pry
  command. e.g: `show-command cd`
* `jump-to NEST_LEVEL`  Unwinds the Pry stack (nesting level) until the appropriate nesting level is reached.
* `exit-all` breaks out of all Pry nesting levels and returns to the
  calling process.
* You can type `Pry.start(obj)` or `obj.pry` to nest another Pry session within the
  current one with `obj` as the receiver of the new session. Very useful
  when exploring large or complicated runtime state.

Bindings and objects
--------------------

Pry ultimately operates on `Binding` objects. If you invoke Pry with a
Binding object it uses that Binding. If you invoke Pry with anything
other than a `Binding`, Pry will generate a Binding for that
object and use that.

If you want to open a Pry session on the current context and capture
the locals you should use: `binding.pry`. If you do not care about
capturing the locals you can simply use `pry` (which will generate a
fresh `Binding` for the receiver).

Top-level is a special case; you can start a Pry session on top-level
*and* capture locals by simply using: `pry`. This is because Pry
automatically uses `TOPLEVEL_BINDING` for the top-level object (main).

Example Programs
----------------

Pry comes bundled with a few example programs to illustrate some
features, see the `examples/` directory.

* `example_basic.rb`             - Demonstrate basic Pry functionality
* `example_input.rb`             - Demonstrates how to set the `input` object.
* `example_output.rb`            - Demonstrates how to set the `output` object.
* `example_hooks.rb`             - Demonstrates how to set the `hooks` hash.
* `example_print.rb`             - Demonstrates how to set the `print` object.
* `example_prompt.rb`            - Demonstrates how to set the `prompt`.
* `example_input2.rb`            - An advanced `input` example.
* `example_commands.rb`          - Implementing a mathematical command set.
* `example_commands_override.rb` - An advanced `commands` example.
* `example_image_edit.rb`        - A simple image editor using a Pry REPL (requires `Gosu` and `TexPlay` gems).

Customizing Pry
---------------

Pry allows a large degree of customization. 

[Read how to customize Pry here.](http://rdoc.info/github/banister/pry/master/file/wiki/Customizing-pry.md)

Contact
-------

Problems or questions contact me at [github](http://github.com/banister)
