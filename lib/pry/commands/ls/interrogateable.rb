module Pry::Command::Ls::Interrogateable

  def interrogating_a_module?
    Module === @interrogatee
  end

  def interrogatee_mod
    if interrogating_a_module?
      @interrogatee
    else
      class << @interrogatee
        ancestors.grep(::Class).reject { |c| c == self }.first
      end
    end
  end

end
