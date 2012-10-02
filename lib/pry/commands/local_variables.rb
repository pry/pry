class Pry
  Pry::Commands.create_command 'local-variables' do
    group 'Context'
    description 'Show hash of local vars, sorted by descending size'

    def process
      pry_vars = [
        :____, :___, :__, :_, :_dir_, :_file_, :_ex_, :_pry_, :_out_, :_in_ ]
      loc_names = target.eval('local_variables').reject do |e|
        pry_vars.include? e
      end
      name_value_pairs = loc_names.map do |name|
        [name, (target.eval name.to_s)]
      end
      name_value_pairs.sort! do |(a,av), (b,bv)|
        bv.to_s.size <=> av.to_s.size
      end
      Pry.print.call _pry_.output, Hash[name_value_pairs]
    end
  end
end
