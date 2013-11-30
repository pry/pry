module Pry::Command::Ls::Interrogateable

  def interrogatee_mod
    if Module === @interrogatee
      @interrogatee
    else
      class << @interrogatee
        ancestors.grep(::Class).reject { |c| c == self }.first
      end
    end
  end

end
