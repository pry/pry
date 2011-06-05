# Note: this requires you to have Gosu and TexPlay installed.
# `gem install gosu`
# `gem install texplay`
#
# Extra instructions for installing Gosu on Linux can be found here:
# http://code.google.com/p/gosu/wiki/GettingStartedOnLinux
#
# Instructions for using TexPlay can be found here:
# http://banisterfiend.wordpress.com/2008/08/23/texplay-an-image-manipulation-tool-for-ruby-and-gosu/
#
# Have fun! :)

require File.expand_path(File.join(File.dirname(__FILE__), 'helper'))

WIDTH = 640
HEIGHT = 480

IMAGE_PROMPT = [ proc { "(image edit)> " }, proc { "(image edit)* " } ]

class ImageCommands < Pry::CommandBase
  command "drawing_methods", "Show a list of TexPlay methods" do
    output.puts "#{Pry.view(TexPlay.public_instance_methods)}"
  end

  command "exit", "Exit the program." do
    output.puts "Thanks for dropping by!"
    exit
  end

  import_from Pry::Commands, "ls", "!"
end

class WinClass < Gosu::Window

  def initialize
    super(WIDTH, HEIGHT, false)
    @img = TexPlay.create_image(self, 200, 200).clear :color => :black
    @img.rect 0, 0, @img.width - 1, @img.height - 1

    @binding = Pry.binding_for(@img)

    @pry_instance = Pry.new(:commands => ImageCommands, :prompt => IMAGE_PROMPT)
  end

  def draw
    @img.draw_rot(WIDTH / 2, HEIGHT / 2, 1, 0, 0.5, 0.5)
  end

  def update
    exit if button_down?(Gosu::KbEscape)

    # We do not want a REPL session as the loop prevents the image
    # being updated; instead we do a REP session, and let the image
    # update each time the user presses enter. We maintain the same
    # binding object to keep locals between calls to `Pry#rep()`
    @pry_instance.rep(@binding)
  end
end

puts "Welcome to ImageEdit; type `help` for a list of commands and `drawing_methods` for a list of drawing methods available."
puts "--"
puts "Example: Try typing 'circle width/2, height/2, 95, :color => :blue, :fill => true'"
puts "If you want to save your image, type: save(\"img.png\")"

w = WinClass.new
w.show

