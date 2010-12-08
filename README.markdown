Pry
=============

(C) John Mair (banisterfiend) 2010

_attach an irb-like session to any object_

Pry is a simple Ruby REPL that specializes in interactively manipulates objects during the running of the program.

Based on some ideas found in this [Ruby-Forum thread](http://www.ruby-forum.com/topic/179060)

`Tweak` provides the `using` method.

* Install the [gem](https://rubygems.org/gems/tweak): `gem install tweak`
* Read the [documentation](http://rdoc.info/github/banister/tweak/master/file/README.markdown)
* See the [source code](http://github.com/banister/tweak)

example: using
-------------------------

With the `using` method we can enhance a core class for the duration
of a block:

    module Tweaks
      
      class String
        def hello
          :hello
        end
      end

      class Fixnum
        Hello = :hello
        
        def bye
          :bye
        end
      end
      
    end

    using Tweaks do
      "john".hello #=> :hello
      5.bye #=> :bye
      Fixnum::Hello #=> :hello
    end

    "john".hello #=> NameError
    
How it works
--------------

Makes use of the `Remix` and `Object2module` libraries. Note that `Tweak`
modifies core classes by what is effectively a module inclusion, this
means you cannot use `Tweak` to override existing functionality but
more to augment and supplement that functionality.

`Tweak` works by doing the following: 

* Looks for top-level classes and modules with the same name as those
defined under the using-module.
* Uses `Object2module` to include the corresponding class/module
defined under the using-module into the top-level class/module of the
same name.
* Uses `Remix` to uninclude that functionality at the end of the
`using` block.

Also look at the [Remix](http://github.com/banister/remix) library's
`temp_include` and `temp_extend` methods for a more general solution than `Tweak`.

Thread Safety
--------------

`Tweak` is not threadsafe.

Limitations
-----------

Does not work with nested modules, e.g `class String::SomethingElse`

This is not intended to be a robust or serious solution, it's just a
little experiment. :)

Companion Libraries
--------------------

Tweak is one of a series of experimental libraries that mess with
the internals of Ruby to bring new and interesting functionality to
the language, see also:

* [Remix](http://github.com/banister/remix) - Makes ancestor chains read/write
* [Object2module](http://github.com/banister/object2module) - Enables you to include/extend Object/Classes.
* [Include Complete](http://github.com/banister/include_complete) - Brings in
  module singleton classes during an include. No more ugly ClassMethods and included() hook hacks.
* [Prepend](http://github.com/banister/prepend) - Prepends modules in front of a class; so method lookup starts with the module
* [GenEval](http://github.com/banister/gen_eval) - A strange new breed of instance_eval
* [LocalEval](http://github.com/banister/local_eval) - instance_eval without changing self

Contact
-------

Problems or questions contact me at [github](http://github.com/banister)



