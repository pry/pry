Pry
=============

(C) John Mair (banisterfiend) 2010

_attach an irb-like session to any object_

Pry is a simple Ruby REPL that specializes in the interactive
manipulation of objects during the running of a program.

* Install the [gem](https://rubygems.org/gems/pry): `gem install pry`
* Read the [documentation](http://rdoc.info/github/banister/pry/master/file/README.markdown)
* See the [source code](http://github.com/banister/pry)

example: prying on an object at runtime 
---------------------------------------

With the `Pry.into()` method we can pry (open an irb-like session) on
an object. In the example below we open a Pry session for the `Test` class and execute a method and add
an instance variable. The program is halted for the duration of the session.

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
    

example: Pry sessions can nest arbitrarily deep so we can pry on
objects inside objects:
----------------------------------------------------------------

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

    # program resumes here


example: Spawn a separate thread so you can use `Pry` to manipulate an
object without halting the program. 
--------------------------------------------------------------------

If we embed our `Pry.into` method inside its own thread we can examine
and manipulate objects without halting the program.

    # Pry.into() without parameters opens up the top-level (main)
    Thread.new { Pry.into }
    
    
Features and limitations
------------------------

Pry is an irb-like clone with an emphasis on interactively examining
and manipulating objects during the running of a program.

Its primary utility is probably in debugging, though it may have other
uses (such as implementing a quake-like console for games, for example). Here is a
list of Pry's features along with some of its limitations given at the
end.

* Pry can be invoked at any time and on any object in the running program.
* Pry sessions can nest arbitrarily deeply -- to go back one level of nesting type 'exit' or 'quit'
* Pry has multi-line support built in.
* Pry implements all the methods in the REPL chain separately: `Pry.r`
for reading; `Pry.re` for eval; `Pry.rep` for printing; and `Pry.repl`
for the loop (`Pry.into` is simply an alias for `Pry.repl`)
      
Contact
-------

Problems or questions contact me at [github](http://github.com/banister)



