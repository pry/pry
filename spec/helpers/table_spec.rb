require_relative '../helper'

describe 'Formatting Table' do
  it 'knows about colorized fitting' do
    t = Pry::Helpers::Table.new %w(hihi), {:column_count => 1}, Pry.new
    expect(t.fits_on_line?(4)).to eq true
    t.items = []
    expect(t.fits_on_line?(4)).to eq true

    t.items = %w(hi hi)
    expect(t.fits_on_line?(4)).to eq true
    t.column_count = 2
    expect(t.fits_on_line?(4)).to eq false

    t.items = %w(
      a   ccc
      bb  dddd
    ).sort
    expect(t.fits_on_line?(8)).to eq true
    expect(t.fits_on_line?(7)).to eq false
  end

  describe 'formatting - should order downward and wrap to columns' do
    FAKE_COLUMNS = 62
    def try_round_trip(expected)
      things = expected.split(/\s+/).sort
      actual = Pry::Helpers.tablify(things, FAKE_COLUMNS, Pry.new).to_s.strip
      [expected, actual].each{|e| e.gsub!(/\s+$/, '')}
      if actual != expected
        bar = '-'*25
        puts \
          bar+'expected'+bar,
          expected,
          bar+'actual'+bar,
          actual
      end
      expect(actual).to eq expected
    end

    it 'should handle a tiny case' do
      try_round_trip(<<-eot)
asdf  asfddd  fdass
      eot
    end

    it 'should handle the basic case' do
      try_round_trip(<<-eot)
aadd            ddasffssdad  sdsaadaasd      ssfasaafssd
adassdfffaasds  f            sdsfasddasfds   ssssdaa
assfsafsfsds    fsasa        ssdsssafsdasdf
      eot
    end

    it 'should handle... another basic case' do
      try_round_trip(<<-EOT)
aaad            dasaasffaasf    fdasfdfss       safdfdddsasd
aaadfasassdfff  ddadadassasdf   fddsasadfssdss  sasf
aaddaafaf       dddasaaaaaa     fdsasad         sddsa
aas             dfsddffdddsdfd  ff              sddsfsaa
adasadfaaffds   dsfafdsfdfssda  ffadsfafsaafa   ss
asddaadaaadfdd  dssdss          ffssfsfafaadss  ssas
asdsdaa         faadf           fsddfff         ssdfssff
asfadsssaaad    fasfaafdssd     s
      EOT
    end

    it 'should handle colors' do
      try_round_trip(<<-EOT)
\e[31maaaaaaaaaa\e[0m                      \e[31mccccccccccccccccccccccccccccc\e[0m
\e[31mbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\e[0m  \e[31mddddddddddddd\e[0m
      EOT
    end

    it 'should handle empty input' do
      try_round_trip('')
    end

    it 'should handle one-token input' do
      try_round_trip('asdf')
    end
  end

  describe 'line length is smaller than the length of the longest word' do
    before do
      element = 'swizzle'
      @elem_len = element.length
      @out = [element, 'crime', 'fun']
    end

    it 'should not raise error' do
      expect { Pry::Helpers.tablify(@out, @elem_len - 1, Pry.new) }.not_to raise_error

    end

    it 'should format output as one column' do
      table = Pry::Helpers.tablify(@out, @elem_len - 1, Pry.new).to_s
      expect(table).to eq "swizzle\ncrime  \nfun    "
    end
  end

  specify 'decide between one-line or indented output' do
    expect(Pry::Helpers.tablify_or_one_line('head', %w(ing), Pry.new)).to eq "head: ing\n"
  end
end
