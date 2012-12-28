class Pry
  class Command::AmendLine < Pry::ClassCommand
    match /amend-line(?: (-?\d+)(?:\.\.(-?\d+))?)?/
    group 'Editing'
    description 'Amend a line of input in multi-line mode.'
    command_options :interpolate => false, :listing => 'amend-line'

    banner <<-'BANNER'
      Amend a line of input in multi-line mode. `amend-line N`, where the N in `amend-line N` represents line to replace.

      Can also specify a range of lines using `amend-line N..M` syntax. Passing '!' as replacement content deletes the line(s) instead.
      e.g amend-line 1 puts 'hello world! # replace line 1'
      e.g amend-line 1..4 !               # delete lines 1..4
      e.g amend-line 3 >puts 'goodbye'    # insert before line 3
      e.g amend-line puts 'hello again'   # no line number modifies immediately preceding line
    BANNER

    def process
      start_line_number, end_line_number, replacement_line = *args

      if eval_string.empty?
        raise CommandError, "No input to amend."
      end

      replacement_line = "" if !replacement_line
      input_array = eval_string.each_line.to_a

      end_line_number = start_line_number.to_i if !end_line_number
      line_range = start_line_number ? (one_index_number(start_line_number.to_i)..one_index_number(end_line_number.to_i))  : input_array.size - 1

      # delete selected lines if replacement line is '!'
      if arg_string == "!"
        input_array.slice!(line_range)
      elsif arg_string.start_with?(">")
        insert_slot = Array(line_range).first
        input_array.insert(insert_slot, arg_string[1..-1] + "\n")
      else
        input_array[line_range] = arg_string + "\n"
      end
      eval_string.replace input_array.join
      run "show-input"
    end
  end

  Pry::Commands.add_command(Pry::Command::AmendLine)
end

