class Pry
  module DefaultCommands

    EasterEggs = Pry::CommandSet.new do

      command(/!s\/(.*?)\/(.*?)/, "") do |source, dest|
        eval_string.gsub!(/#{source}/) { dest }
        run "show-input"
      end

      command "get-naked" "" do
        text = %{
--
We dont have to take our clothes off to have a good time.
We could dance & party all night And drink some cherry wine.
-- Jermaine Stewart }
        output.puts text
        text
      end

      command "east-coker", "" do
        text = %{
--
Now the light falls
Across the open field, leaving the deep lane
Shuttered with branches, dark in the afternoon,
Where you lean against a bank while a van passes,
And the deep lane insists on the direction
Into the village, in the electric heat
Hypnotised. In a warm haze the sultry light
Is absorbed, not refracted, by grey stone.
The dahlias sleep in the empty silence.
Wait for the early owl.
-- T.S Eliot
            }
        output.puts text
        text
      end

      command "cohen-poem", "" do
        text = %{
--
When this American woman,
whose thighs are bound in casual red cloth,
comes thundering past my sitting place
like a forest-burning Mongol tribe,
the city is ravished
and brittle buildings of a hundred years
splash into the street;
and my eyes are burnt
for the embroidered Chinese girls,
already old,
and so small between the thin pines
on these enormous landscapes,
that if you turn your head
they are lost for hours.
                  -- Leonard Cohen
                }
  output.puts text
  text
end


    end

  end
end
