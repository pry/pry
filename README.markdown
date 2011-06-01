![Alt text](http://dl.dropbox.com/u/15761219/pry_horizontal_red.png)

(C) John Mair (banisterfiend) 2011

_Get to the code_

Pry is a powerful alternative to the standard IRB shell for Ruby. It is
written from scratch to provide a number of advanced features, some of
these include:

* Source code browsing (including core C source with the pry-doc gem)
* Documentation browsing
* Live help system
* Open methods in editors (`edit-method Class#method`)
* Syntax highlighting
* Command shell integration (start editors, run git, and rake from within Pry)
* Gist integration
* Navigation around state (`cd`, `ls` and friends)
* Runtime invocation (use Pry as a developer console or debugger)
* Exotic object support (BasicObject instances, IClasses, ...)
* A Powerful and flexible command system
* Ability to view and replay history
* Many convenience commands inspired by IPython and other advanced REPLs

Pry also aims to be more than an IRB replacement; it is an
attempt to bring REPL driven programming to the Ruby language. It is
currently not nearly as powerful as tools like [SLIME](http://en.wikipedia.org/wiki/SLIME) for lisp, but that is the
general direction Pry is heading.

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

### Commands

Nearly every piece of functionality in a Pry session is implemented as
a command. Commands are not methods and must start at the beginning of a line, with no
whitespace in between. Commands support a flexible syntax and allow
'options' in the same way as shell commands, for example the following
Pry command will show a list of all private instance methods (in
scope) that begin with 'pa'

    pry(YARD::Parser::SourceParser):5> ls -Mp --grep pa
    [:parser_class, :parser_type=, :parser_type_for_filename]

### Navigating around state

Pry allows us to pop in and out of different scopes (objects) using
the `cd` command. This enables us to explore the run-time view of a
program or library. To view which variables and methods are available
within a particular scope we use the versatile [ls command.](https://gist.github.com/c0fc686ef923c8b87715)

Here we will begin Pry at top-level, then Pry on a class and then on
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

### Runtime invocation

Pry can be invoked in the middle of a running program. It opens a Pry
session at the point it's called and makes all program state at that
point available. It can be invoked on any object using the
`my_object.pry` syntax or on the current binding (or any binding)
using `binding.pry`. The Pry session will then begin within the scope
of the object (or binding). When the session ends the program continues with any
modifications you made to it.

This functionality can be used for such things as: debugging,
implementing developer consoles and applying hot patches.

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

    program resumes here.

### Command Shell Integration

A line of input that begins with a '.' will be forwarded to the
command shell. This enables us to navigate the file system, spawn
editors, and run git and rake directly from within Pry.

Further, we can use the `shell-mode` command to incorporate the
present working directory into the Pry prompt and bring in (limited at this stage, sorry) file name completion.
We can also interpolate Ruby code directly into the shell by
using the normal `#{}` string interpolation syntax.

In the code below we're going to switch to `shell-mode` and edit the
`.pryrc` file in the home directory. We'll then cat its contents and
reload the file.

    pry(main)> shell-mode
    pry main:/home/john/ruby/projects/pry $ .cd ~
    pry main:/home/john $ .emacsclient .pryrc
    pry main:/home/john $ .cat .pryrc
    def hello_world
      puts "hello world!"
    end
    pry main:/home/john $ load ".pryrc"
    => true
    pry main:/home/john $ hello_world
    hello world!

We can also interpolate Ruby code into the shell. In the
example below we use the shell command `cat` on a random file from the
current directory and count the number of lines in that file with
`wc`:

    pry main:/home/john $ .cat #{Dir['*.*'].sample} | wc -l
    44

### Code Browsing

#### show-method

You can browse method source code with the `show-method` command. Nearly all Ruby methods (and some C methods, with the pry-doc
gem) can have their source viewed. Code that is longer than a page is
sent through a pager (such as less), and all code is properly syntax
highlighted (even C code).

The `show-method` command accepts two syntaxes, the typical ri
`Class#method` syntax and also simply the name of a method that's in
scope. You can optionally pass the `-l` option to show-method to
include line numbers in the output.

In the following example we will enter the `Pry` class, list the
instance methods beginning with 're' and display the source code for the `rep` method:

    pry(main)> cd Pry
    pry(Pry):1> ls -M --grep ^re
    [:re, :readline, :rep, :repl, :repl_epilogue, :repl_prologue, :retrieve_line]
    pry(Pry):1> show-method rep -l

    From: /home/john/ruby/projects/pry/lib/pry/pry_instance.rb @ line 143:
    Number of lines: 6

    143: def rep(target=TOPLEVEL_BINDING)
    144:   target = Pry.binding_for(target)
    145:   result = re(target)
    146:
    147:   show_result(result) if should_print?
    148: end

Note that we can also view C methods (from Ruby Core) using the
`pry-doc` gem; we also show off the alternate syntax for
`show-method`:

    pry(main)> show-method Array#select

    From: array.c in Ruby Core (C Method):
    Number of lines: 15

    static VALUE
    rb_ary_select(VALUE ary)
    {
        VALUE result;
        long i;

        RETURN_ENUMERATOR(ary, 0, 0);
        result = rb_ary_new2(RARRAY_LEN(ary));
        for (i = 0; i < RARRAY_LEN(ary); i++) {
        if (RTEST(rb_yield(RARRAY_PTR(ary)[i]))) {
            rb_ary_push(result, rb_ary_elt(ary, i));
        }
        }
        return result;
    }

#### Special locals

Some commands such as `show-method`, `show-doc`, `show-command`, `stat`
and `cat` update the `_file_` and `_dir_` local variables after they
run. These locals contain the full path to the file involved in the
last command as well as the directory containing that file.

You can then use these special locals in conjunction with shell
commands to do such things as change directory into the directory
containing the file, open the file in an editor, display the file using `cat`, and so on.

In the following example we wil use Pry to fix a bug in a method:

    pry(main)> greet "john"
    hello johnhow are you?=> nil
    pry(main)> show-method greet

    From: /Users/john/ruby/play/bug.rb @ line 2:
    Number of lines: 4

    def greet(name)
      print "hello #{name}"
      print "how are you?"
    end
    pry(main)> .emacsclient #{_file_}
    pry(main)> load _file_
    pry(main)> greet "john"
    hello john
    how are you?
    => nil
    pry(main)> show-method greet

    From: /Users/john/ruby/play/bug.rb @ line 2:
    Number of lines: 4

    def greet(name)
      puts "hello #{name}"
      puts "how are you?"
    end


### Documentation Browsing

One use-case for Pry is to explore a program at run-time by `cd`-ing
in and out of objects and viewing and invoking methods. In the course
of exploring it may be useful to read the documentation for a
specific method that you come across. Like `show-method` the `show-doc` command supports
two syntaxes - the normal `ri` syntax as well as accepting the name of
any method that is currently in scope.

The Pry documentation system does not rely on pre-generated `rdoc` or
`ri`, instead it grabs the comments directly above the method on
demand. This results in speedier documentation retrieval and allows
the Pry system to retrieve documentation for methods that would not be
picked up by `rdoc`. Pry also has a basic understanding of both the
rdoc and yard formats and will attempt to syntax highlight the
documentation appropriately.

Nonetheless The `ri` functionality is very good and
has an advantage over Pry's system in that it allows documentation
lookup for classes as well as methods. Pry therefore has good
integration with  `ri` through the `ri` command. The syntax
for the command is exactly as it would be in command-line -
so it is not necessary to quote strings.

In our example we will enter the `Gem` class and view the
documentation for the `try_activate` method:

    pry(main)> cd Gem
    pry(Gem):1> show-doc try_activate

    From: /Users/john/.rvm/rubies/ruby-1.9.2-p180/lib/ruby/site_ruby/1.9.1/rubygems.rb @ line 201:
    Number of lines: 3

    Try to activate a gem containing path. Returns true if
    activation succeeded or wasn't needed because it was already
    activated. Returns false if it can't find the path in a gem.
    pry(Gem):1>

We can also use `ri` in the normal way:

    pry(main) ri Array#each
    ----------------------------------------------------------- Array#each
         array.each {|item| block }   ->   array
    ------------------------------------------------------------------------
         Calls _block_ once for each element in _self_, passing that element
         as a parameter.

            a = [ "a", "b", "c" ]
            a.each {|x| print x, " -- " }

         produces:

            a -- b -- c --


### History

Readline history can be viewed and replayed using the `hist`
command. When `hist` is invoked with no arguments it simply displays
the history (passing the output through a pager if necessary))
when the `--replay` option is used a line or a range of lines of
history can be replayed.

In the example below we will enter a few lines in a Pry session and
then view history; we will then replay one of those lines:

    pry(main)> hist
    0: hist -h
    1: ls
    2: ls
    3: show-method puts
    4: x = rand
    5: hist
    pry(main)> hist --replay 3

    From: io.c in Ruby Core (C Method):
    Number of lines: 8

    static VALUE
    rb_f_puts(int argc, VALUE *argv, VALUE recv)
    {
        if (recv == rb_stdout) {
        return rb_io_puts(argc, argv, recv);
        }
        return rb_funcall2(rb_stdout, rb_intern("puts"), argc, argv);
    }

In the next example we will replay a range of lines in history. Note
that we replay to a point where a class definition is still open and so
we can continue to add instance methods to the class:

    pry(main)> hist
    0: class Hello
    1:   def hello_world
    2:     puts "hello world!"
    3:   end
    4: end
    5: hist
    pry(main)> hist --replay 0..3
    pry(main)* def goodbye_world
    pry(main)*   puts "goodbye world!"
    pry(main)* end
    pry(main)* end
    => nil
    pry(main)> Hello.new.goodbye_world;
    goodbye world!
    pry(main)>

Also note that in the above the line `Hello.new.goodbye_world;` ends
with a semi-colon which causes expression evaluation output to be suppressed.

### Gist integration

If the `gist` gem is installed then method source or documentation can be gisted to github with the
`gist-method` command. The `gist-method` command accepts the same two
syntaxes as `show-method`. In the example below we will gist the C source
code for the `Symbol#to_proc` method to github:

    pry(main)> gist-method Symbol#to_proc
    https://gist.github.com/5332c38afc46d902ce46
    pry(main)>

You can see the actual gist generated here: [https://gist.github.com/5332c38afc46d902ce46](https://gist.github.com/5332c38afc46d902ce46)

### Edit methods

You can use `edit-method Class#method` or `edit-method my_method`
(if the method is in scope) to open a method for editing directly in
your favorite editor. Pry has knowledge of a few different editors and
will attempt to open the file at the line the method is defined.

You can set the editor to use by assigning to the `Pry.editor`
accessor. `Pry.editor` will default to `$EDITOR` or failing that will
use `nano` as the backup default. The file that is edited will be
automatically reloaded after exiting the editor - reloading can be
suppressed by passing the `--no-reload` option to `edit-method`

In the example below we will set our default editor to "emacsclient"
and open the `Pry#repl` method for editing:

    pry(main)> Pry.editor = "emacsclient"
    pry(main)> edit-method Pry#repl

### Live Help System

Many other commands are available in Pry; to see the full list type
`help` at the prompt. A short description of each command is provided
with basic instructions for use; some commands have a more extensive
help that can be accessed via typing `command_name --help`. A command
will typically say in its description if the `--help` option is
avaiable.

### Use Pry as your Rails Console

    pry -r./config/environment

MyArtChannel has kindly provided a hack to replace the `rails console` command in Rails 3: [https://gist.github.com/941174](https://gist.github.com/941174) This is not recommended for code bases with multiple developers, as they may not all want to use Pry.

### Other Features and limitations

#### Other Features:

* Pry can be invoked both at the command-line and used as a more
powerful alternative to IRB or it can be invoked at runtime and used
as a developer consoler / debugger.
* Additional documentation and source code for Ruby Core methods are supported when the `pry-doc` gem is installed.
* Pry sessions can nest arbitrarily deeply -- to go back one level of nesting type 'exit' or 'quit' or 'back'
* Pry comes with syntax highlighting on by default just use the `toggle-color` command to turn it on and off.
* Use `_` to recover last result.
* Use `_pry_` to reference the Pry instance managing the current session.
* Use `_ex_` to recover the last exception.
* Use `_file_` and `_dir_` to refer to the associated file or
  directory containing the definition for a method.
* A trailing `;` on an entered expression suppresses the display of
  the evaluation output.
* Typing `!` on a line by itself will clear the input buffer - useful for
  getting you out of a situation where the parsing process
  goes wrong and you get stuck in an endless read loop.
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

#### Limitations:

* Some Pry commands (e.g `show-command`) do not work in Ruby 1.8
  MRI. But many other commands do work in Ruby 1.8 MRI, e.g
  `show-method`, due to a functional 1.8 source_location implementation.
* JRuby not officially supported due to currently too many quirks and
 strange behaviour. Nonetheless most functionality should still work
 OK in JRuby. Full JRuby support coming in a future version.
* `method_source` functionality does not work in JRuby with Ruby 1.8
* Tab completion is currently a bit broken/limited this will have a
   major overhaul in a future version.

### Syntax Highlighting

Syntax highlighting is on by default in Pry. You can toggle it on and
off in a session by using the `toggle-color` command. Alternatively,
you can turn it off permanently by putting the line `Pry.color =
false` in your `~/.pryrc` file.

### Example Programs

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

### Customizing Pry

Pry allows a large degree of customization.

[Read how to customize Pry here.](http://rdoc.info/github/banister/pry/master/file/wiki/Customizing-pry.md)

### Future Directions

Many new features are planned such as:

* Much improved tab completion (using [Bond](http://github.com/cldwalker/bond))
* Improved JRuby support
* Support for viewing source-code of binary gems and C stdlib
* git integration
* Much improved documentation system, better support for YARD
* A proper plugin system
* Get rid of `.` prefix for shell commands in `shell-mode`
* Better support for code and method reloading
* Extended and more sophisticated command system, allowing piping
between commands and running commands in background

### Contact

Problems or questions contact me at [github](http://github.com/banister)

### Contributors

The Pry team consists of:

* [banisterfiend](http://github.com/banister)
* [epitron](http://github.com/epitron)
* [injekt](http://github.com/injekt)
* [Mon_Ouie](http://github.com/mon-ouie)


