require 'pry/helpers/documentation_helpers'
require 'forwardable'

class Pry
  class WrappedModule

    # This class represents a single candidate for a module/class definition.
    # It provides access to the source, documentation, line and file
    # for a monkeypatch (reopening) of a class/module.
    class Candidate
      include Pry::Helpers::DocumentationHelpers
      extend Forwardable

      # @return [String] The file where the module definition is located.
      attr_reader :file

      # @return [Fixnum] The line where the module definition is located.
      attr_reader :line

      # Methods to delegate to associated `Pry::WrappedModule instance`.
      to_delegate = [:lines_for_file, :method_candidates, :name, :wrapped,
                     :yard_docs?, :number_of_candidates]

      def_delegators :@wrapper, *to_delegate
      private *to_delegate

      # @raise [Pry::CommandError] If `rank` is out of bounds.
      # @param [Pry::WrappedModule] wrapper The associated
      #   `Pry::WrappedModule` instance that owns the candidates.
      # @param [Fixnum] rank The rank of the candidate to
      #   retrieve. Passing 0 returns 'primary candidate' (the candidate with largest
      #   number of methods), passing 1 retrieves candidate with
      #   second largest number of methods, and so on, up to
      #   `Pry::WrappedModule#number_of_candidates() - 1`
      def initialize(wrapper, rank)
        @wrapper = wrapper

        if number_of_candidates <= 0
          raise CommandError, "Cannot find a definition for #{name} module!"
        elsif rank > (number_of_candidates - 1)
          raise CommandError, "No such module candidate. Allowed candidates range is from 0 to #{number_of_candidates - 1}"
        end

        @rank = rank
        @file, @line = source_location
      end

      # @raise [Pry::CommandError] If source code cannot be found.
      # @return [String] The source for the candidate, i.e the
      #   complete module/class definition.
      def source
        return @source if @source

        raise CommandError, "Could not locate source for #{wrapped}!" if file.nil?
        end_line = end_method_source_location.last

        num_lines = end_line - line
        @source = strip_leading_whitespace(Pry::Code.from_file(file).expression_at(line, num_lines))
      end

      # @raise [Pry::CommandError] If documentation cannot be found.
      # @param [Boolean] check_yard Try to retrieve yard docs instead
      #   (if they exist), otherwise attempt to return the docs for the
      #   discovered module definition. `check_yard` is only relevant
      #   for the primary candidate (rank 0) candidate.
      # @return [String] The documentation for the candidate.
      def doc(check_yard=true)
        return @doc if @doc

        docstring = if check_yard && @rank == 0 && yard_docs?
                      from_yard = YARD::Registry.at(name).docstring.to_s
                      from_yard.empty? ? nil : from_yard
                    elsif source_location.nil?
                      nil
                    else
                      Pry::Code.from_file(file).comment_describing(line)
                    end

        raise CommandError, "Could not locate doc for #{wrapped}!" if docstring.nil? || docstring.empty?

        @doc = process_doc(docstring)
      end

      # @return [Array, nil] A `[String, Fixnum]` pair representing the
      #   source location (file and line) for the candidate or `nil`
      #   if no source location found.
      def source_location
        return @source_location if @source_location

        mod_type_string = wrapped.class.to_s.downcase
        file, line = start_method_source_location

        return nil if !file.is_a?(String)

        class_regexes = [/^\s*#{mod_type_string}\s*(\w*)(::)?#{wrapped.name.split(/::/).last}/,
                         /^\s*(::)?#{wrapped.name.split(/::/).last}\s*?=\s*?#{wrapped.class}/,
                         /^\s*(::)?#{wrapped.name.split(/::/).last}\.(class|instance)_eval/]

        host_file_lines = lines_for_file(file)

        search_lines = host_file_lines[0..(line - 2)]
        idx = search_lines.rindex { |v| class_regexes.any? { |r| r =~ v } }

        @source_location = [file,  idx + 1]
      rescue Pry::RescuableException
        nil
      end

      private

      # This method is used by `Candidate#source_location` as a
      # starting point for the search for the candidate's definition.
      # @return [Array] The source location of the base method used to
      #   calculate the source location of the candidate.
      def start_method_source_location
        adjusted_source_location(method_candidates[@rank].first.source_location)
      end

      def end_method_source_location
        adjusted_source_location(method_candidates[@rank].last.source_location)
      end

      def adjusted_source_location(sl)
        file, line = sl

        if file && RbxPath.is_core_path?(file)
          file = RbxPath.convert_path_to_full(file)
        end

        [file, line]
      end

      # @param [String] doc The raw docstring to process.
      # @return [String] Process docstring markup and strip leading white space.
      def process_doc(doc)
         process_comment_markup(strip_leading_hash_and_whitespace_from_ruby_comments(doc),
                                :ruby)
      end
    end
  end
end
