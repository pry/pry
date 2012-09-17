class Pry
  Pry::Commands.create_command "ri" do
    group 'Introspection'
    description "View ri documentation. e.g `ri Array#each`"

    banner <<-BANNER
      Usage: ri [spec]
      e.g. ri Array#each

      Relies on the rdoc gem being installed. See also: show-doc.
    BANNER

    def process(spec)
      # Lazily load RI
      require 'rdoc/ri/driver'

      unless defined? RDoc::RI::PryDriver

        # Subclass RI so that it formats its output nicely, and uses `lesspipe`.
        subclass = Class.new(RDoc::RI::Driver) # the hard way.

        subclass.class_eval do
          def page
            paging_text = StringIO.new
            yield paging_text
            Pry::Pager.page(paging_text.string)
          end

          def formatter(io)
            if @formatter_klass then
              @formatter_klass.new
            else
              RDoc::Markup::ToAnsi.new
            end
          end
        end

        RDoc::RI.const_set :PryDriver, subclass   # hook it up!
      end

      # Spin-up an RI insance.
      ri = RDoc::RI::PryDriver.new :use_stdout => true, :interactive => false

      begin
        ri.display_names [spec]  # Get the documentation (finally!)
      rescue RDoc::RI::Driver::NotFoundError => e
        output.puts "error: '#{e.name}' not found"
      end
    end
  end
end
