Pry
=============

(C) John Mair (banisterfiend) 2010

_attach an irb-like session to any object at runtime_

Pry is a simple Ruby REPL (Read-Eval-Print-Loop) that specializes in the interactive
manipulation of objects during the running of a program.

* Install the [gem](https://rubygems.org/gems/pry): `gem install pry`
* Read the [documentation](http://rdoc.info/github/banister/pry/master/file/README.markdown)
* See the [source code](http://github.com/banister/pry)

example: Interacting with an object at runtime 
---------------------------------------

With the `Pry.into()` method we can pry (open an irb-like session) on
an object. In the example below we open a Pry session for the `Test` class and execute a method and add
an instance variable. The current thread is halted for the duration of the session.

    require 'pry'
    
    class Test
      def self.hello() "hello world" end
    end

    Pry.into(Test)

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
    

example: Pry sessions can nest arbitrarily deep so we can pry on objects inside objects:
----------------------------------------------------------------------------------------

Here we will begin Pry at top-level, then pry on a class and then on
an instance variable inside that class:

    # Pry.into() without parameters begins a Pry session on top-level (main)
    Pry.into
    Beginning Pry session for main
    pry(main)> class Hello
    pry(main)*   @x = 20
    pry(main)* end
    => 20
    pry(main)> Pry.into Hello
    Beginning Pry session for Hello
    pry(Hello)> instance_variables
    => [:@x]
    pry(Hello)> Pry.into @x
    Beginning Pry session for 20
    pry(20)> self + 10
    => 30
    pry(20)> exit
    Ending Pry session for 20
    pry(Hello)> exit
    Ending Pry session for Hello
    pry(main)> exit
    Ending Pry session for main
    

Features and limitations
------------------------

Pry is an irb-like clone with an emphasis on interactively examining
and manipulating objects during the running of a program.

Its primary utility is probably in debugging, though it may have other
uses (such as implementing a quake-like console for games, for example). Here is a
list of Pry's features along with some of its limitations given at the
end.

Features:

* Pry can be invoked at any time and on any object in the running program.
* Pry sessions can nest arbitrarily deeply -- to go back one level of nesting type 'exit' or 'quit'
* Pry has multi-line support built in.
* Pry is not based on the IRB codebase.
* Pry is Only 120 LOC.
* Pry implements all the methods in the REPL chain separately: `Pry.r`
for reading; `Pry.re` for eval; `Pry.rep` for printing; and `Pry.repl`
for the loop (`Pry.into` is simply an alias for `Pry.repl`). You can
invoke any of these methods directly depending on exactly what aspect of the functionality you need.

Limitations:

* Pry does not pretend to be a replacement for `irb`,
  and so does not have an executable. It is designed to be used by
  other programs, not on its own. For a full-featured `irb` replacement
  see [ripl](https://github.com/cldwalker/ripl)
* Although Pry works fine in Ruby 1.9, only Ruby 1.8 syntax is
  supported. This is because Pry uses the
  [RubyParser](https://github.com/seattlerb/ruby_parser)
  gem internally to  validate expressions, and RubyParser, as yet, only parses Ruby 1.8
  code. In practice this usually just means you cannot use the new
  hash literal syntax (this: syntax) or the 'stabby lambda' syntax
  (->).
 
Commands
-----------

The Pry API:

* `Pry.into()` and `Pry.start()` and `Pry.repl()` are all aliases of
oneanother. They all start a Read-Eval-Print-Loop on the object they
receive as a parameter. In the case of no parameter they operate on
top-level (main). They can receive any object or a `Binding`
object as parameter.
* If, for some reason you do not want to 'loop' then use `Pry.rep()`; it
only performs the Read-Eval-Print section of the REPL - it ends the
session after just one line of input. It takes the same parameters as
`Pry.repl()`
* Likewise `Pry.re()` only performs the Read-Eval section of the REPL,
it returns the result of the evaluation. It also takes the same parameters as `Pry.repl()`
* Similarly `Pry.r()` only performs the Read section of the REPL, only
returning the Ruby expression (as a string) or an Exception object in
case of error. It takes the same parameters as all the others.

Pry supports a few commands inside the session itself:

* Typing `!` on a line by itself will refresh the REPL - useful for
  getting you out of a situation if the parsing process
  goes wrong.
* `exit` or `quit` will end the current Pry session. Note that it will
  not end any containing Pry sessions if the current session happens
  to be nested.
* `#exit` or `#quit` will end the currently running program.
* You can type `Pry.into(obj)` to nest another Pry session within the
  current one with `obj` as the receiver of the new session. Very useful
  when exploring large or complicated runtime state.

Contact
-------

Problems or questions contact me at [github](http://github.com/banister)



