Pry
=============

(C) John Mair (banisterfiend) 2010

_attach an irb-like session to any object at runtime_

Pry is a simple Ruby REPL (Read-Eval-Print-Loop) that specializes in the interactive
manipulation of objects during the running of a program. 

It is not based on the IRB codebase, and implements some unique REPL
commands such as `show_method` and `show_doc`

* Install the [gem](https://rubygems.org/gems/pry): `gem install pry`
* Read the [documentation](http://rdoc.info/github/banister/pry/master/file/README.markdown)
* See the [source code](http://github.com/banister/pry)

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
    pry(main)> Hello.pry
    Beginning Pry session for Hello
    pry(Hello):1> instance_variables
    => [:@x]
    pry(Hello):1> @x.pry
    Beginning Pry session for 20
    pry(20:2)> self + 10
    => 30
    pry(20:2)> exit
    Ending Pry session for 20
    pry(Hello):1> exit
    Ending Pry session for Hello
    pry(main)> exit
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
the `jump_to` command:

    pry("friend":3)> jump_to 1
    Ending Pry session for "friend"
    Ending Pry session for 100
    => 100
    pry(Hello):1>

If we just want to go back one level of nesting we can of course
use the `quit` or `exit` or `back` commands.

To break out of all levels of Pry nesting and return immediately to the
calling process use `exit_all`:

    pry("friend":3)> exit_all
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
* Pry has special commands not found in many other Ruby REPLs: `show_method`, `show_doc`
`jump_to`, `ls`, `cd`, `cat`
* Pry gives good control over nested sessions (important when exploring complicated runtime state)
* Pry is not based on the IRB codebase.
* Pry allows significant customizability.
* Pry uses [RubyParser](https://github.com/seattlerb/ruby_parser) to
validate expressions in 1.8, and [Ripper](http://rdoc.info/docs/ruby-core/1.9.2/Ripper) for 1.9.
* Pry implements all the methods in the REPL chain separately: `Pry#r`
for reading; `Pry#re` for eval; `Pry#rep` for printing; and `Pry#repl`
for the loop (`Pry.start` simply wraps `Pry.new.repl`). You can
invoke any of these methods directly depending on exactly what aspect of the functionality you need.

###Limitations:

* Pry does not pretend to be a replacement for `irb`,
  and so does not have an executable. It is designed to be used by
  other programs, not on its own. For a full-featured `irb` replacement
  see [ripl](https://github.com/cldwalker/ripl)
* Pry's `show_method` and `show_doc` commands do not work
  in Ruby 1.8.

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

### Session commands

Pry supports a few commands inside the session itself. These commands are
not methods and must start at the beginning of a line, with no
whitespace in between.

If you want to access a method of the same name, prefix the invocation by whitespace.

* Typing `!` on a line by itself will refresh the REPL - useful for
  getting you out of a situation if the parsing process
  goes wrong.
* `status` shows status information about the current session.
* `help` shows the list of session commands with brief explanations.
* `exit` or `quit` or `back` will end the current Pry session and go
  back to the calling process or back one level of nesting (if there
  are nested sessions).
* `ls` returns a list of local variables and instance variables in the
  current scope
* `ls_methods` List all methods defined on immediate class of receiver.
* `ls_imethods` List all instance methods defined on receiver.
* `cat <var>` Calls `inspect` on `<var>`
* `cd <var>` Starts a `Pry` session on the variable <var>. E.g `cd @x`
* `show_method <methname>` Displays the sourcecode for the method
  <methname>. E.g `show_method hello`
* `show_imethod <methname>` Displays the sourcecode for the
  instance method <methname>. E.g `show_imethod goodbye`
* `show_doc <methname>` Displays comments for `<methname>`
* `show_idoc <methname>` Displays comments for instance
  method `<methname>`
* `exit_program` or `quit_program` will end the currently running
  program.
* `nesting` Shows Pry nesting information.
* `!pry` Starts a Pry session on the implied receiver; this can be
  used in the middle of an expression in multi-line input.
* `jump_to <nest_level>`  Unwinds the Pry stack (nesting level) until the appropriate nesting level is reached
  -- as per the output of `nesting`
* `exit_all` breaks out of all Pry nesting levels and returns to the
  calling process.
* You can type `Pry.start(obj)` or `obj.pry` to nest another Pry session within the
  current one with `obj` as the receiver of the new session. Very useful
  when exploring large or complicated runtime state.

Example Programs
----------------

Pry comes bundled with a few example programs to illustrate some
features, see the `examples/` directory.

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

Pry supports customization of the input, the output, the commands,
the hooks, the prompt, and 'print' (the "P" in REPL).

[Read how to customize Pry here.](http://rdoc.info/github/banister/pry/master/file/wiki/Customizing-pry.md)

Contact
-------

Problems or questions contact me at [github](http://github.com/banister)




