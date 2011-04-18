![Alt text](http://dl.dropbox.com/u/26521875/pry_logo.png)

 
(C) John Mair (banisterfiend) 2011

_Get to the code_

Pry is a powerful alternative to the standard IRB shell for Ruby. It is
written from scratch to provide a number of advanced features, some of
these include:

* Syntax highlighting
* Navigation around state (`cd`, `ls` and friends)
* Runtime invocation (use Pry as a developer console or debugger)
* Command shell integration
* Source code browsing (including core C source with the pry-doc gem)
* Documentation browsing 
* Exotic object support (BasicObject instances, IClasses, ...)
* A Powerful and flexible command system
* Ability to view and replay history
* Many convenience commands inspired by IPython and other advanced REPLs


Pry is also fairly flexible and allows significant user
[customization](http://rdoc.info/github/banister/pry/master/file/wiki/Customizing-pry.md). It
is trivial to set it to read from any object that has a `readline` method and write to any object that has a
`puts` method - many other aspects of Pry are also configurable making
it a good choice for implementing custom shells.

Pry comes with an executable so it can be invoked at the command line.
Just enter `pry` to start. A `.pryrc` file in the user's home directory will
be loaded if it exists. Type `pry --help` at the command line for more
information.

Try `gem install pry-doc` for additional documentation on Ruby Core
methods. The additional docs are accessed through the `show-doc` and
`show-method` commands.

* Install the [gem](https://rubygems.org/gems/pry): `gem install pry`
* Read the [documentation](http://rdoc.info/github/banister/pry/master/file/README.markdown)
* See the [source code](http://github.com/banister/pry)

Pry also has `rubygems-test` support; to participate, first install
Pry, then:

1. Install rubygems-test: `gem install rubygems-test`
2. Run the test: `gem test pry`
3. Finally choose 'Yes' to upload the results. 

Example: Navigating around state
---------------------------------------

Pry allows us to pop in and out of different scopes (objects) using
the `cd` command. To view what variables and methods are available
within a particular scope we use the versatile `ls` command. 

Here we will begin Pry at top-level, then pry on a class and then on
an instance variable inside that class:

    pry(main)> class Hello
    pry(main)*   @x = 20
    pry(main)* end
    => 20
    pry(main)> cd Hello
    pry(Hello):1> ls -i
    => [:@x]
    pry(Hello):1> cd @x
    pry(20:2)> self + 10
    => 30
    pry(20:2)> cd ..
    pry(Hello):1> cd ..
    pry(main)> cd ..

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

Example: Runtime invocation
---------------------------------------

Pry can be invoked in the middle of a running program. It opens a Pry
session at the point it’s called and makes all program state at that
point available.

When the session ends the program continues with any
modifications you made to it.

This functionality can be used for such things as: debugging,
implementing developer consoles, and applying hot patches.

code:

    # test.rb
    require 'pry'
    
    class A
      def hello() puts "hello world!" end
    end
    
    a = A.new
    
    # start a REPL session
    binding.pry
    
    # program resumes here (after pry session)
    puts "program resumes here."

Pry session:

    pry(main)> a.hello
    hello world!
    => nil
    pry(main)> def a.goodbye
    pry(main)*   puts "goodbye cruel world!"
    pry(main)* end
    => nil
    pry(main)> a.goodbye
    goodbye cruel world!
    => nil
    pry(main)> exit

    # program resumes here.
    

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
* Additional documentation and source code for Ruby Core methods are supported when the `pry-doc` gem is installed.
* Pry sessions can nest arbitrarily deeply -- to go back one level of nesting type 'exit' or 'quit' or 'back'
* Pry comes with syntax highlighting on by default just use the `toggle-color` command to turn it on and off.
* Use `_` to recover last result.
* Use `_pry_` to reference the Pry instance managing the current session.
* Use `_ex_` to recover the last exception.
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
* `method_source` functionality does not work in JRuby.
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
* `whereami AROUND` shows the code context of the session. Shows
  AROUND lines either side of the current line.
* `version` Show Pry version information
* `help` shows the list of session commands with brief explanations.
* `toggle-color` turns on and off syntax highlighting.
* `simple-prompt` toggles the simple prompt mode.
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

Syntax Highlighting
--------------------

Syntax highlighting is on by default in Pry. You can toggle it on and
off in a session by using the `toggle-color` command. Alternatively,
you can turn it off permanently by putting the line `Pry.color =
false` in your `~/.pryrc` file.

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
