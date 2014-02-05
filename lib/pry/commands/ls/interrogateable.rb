module Pry::Command::Ls::Interrogateable

  private

  def interrogating_a_module?
    Module === @interrogatee
  end

  def interrogatee_mod
    if interrogating_a_module?
      @interrogatee
    else
      singleton = Pry::Method.singleton_class_of(@interrogatee)
      singleton.ancestors.grep(::Class).reject { |c| c == singleton }.first
    end
  end

end
