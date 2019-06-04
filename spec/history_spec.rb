# frozen_string_literal: true

require 'tempfile'
require 'rbconfig'

RSpec.describe Pry::History do
  before do
    Pry.history.clear

    @saved_history = "1\n2\n3\ninvalid\0 line\n"

    Pry.history.loader = proc do |&blk|
      @saved_history.lines.each { |l| blk.call(l) }
    end

    Pry.load_history
  end

  after do
    Pry.history.clear
    Pry.history.instance_variable_set(:@original_lines, 0)
  end

  describe ".default_file" do
    let(:xdg_name) { 'XDG_DATA_HOME' }
    let(:default_path) { File.expand_path '~/.pry_history' }

    def stub_hist(options)
      has_default = options.fetch :has_default
      xdg_home    = options.fetch :xdg_home
      allow(File).to receive(:exist?) # there's a test helper hook that hits this
      allow(File).to receive(:exist?).with(default_path).and_return(has_default)
      allow(ENV).to receive(:[])
      allow(ENV).to receive(:key?)
      allow(ENV).to receive(:[]).with(xdg_name).and_return(xdg_home)
      allow(ENV).to receive(:key?).with(xdg_name).and_return(!!xdg_home)
    end

    it "returns ~/.local/share/pry/pry_history" do
      stub_hist has_default: false, xdg_home: nil
      expect(described_class.default_file).to match('/.local/share/pry/pry_history')
    end

    context "when ~/.pry_history exists" do
      it "returns ~/.pry_history" do
        stub_hist has_default: true, xdg_home: nil
        expect(described_class.default_file).to eq default_path
      end
    end

    context "when $XDG_DATA_HOME is defined" do
      it "returns config location relative to $XDG_DATA_HOME" do
        stub_hist has_default: false, xdg_home: '/my/path'
        expect(described_class.default_file).to eq('/my/path/pry/pry_history')
      end

      it "returns config location relative to $XDG_DATA_HOME when ~/.pryrc exists" do
        stub_hist has_default: true, xdg_home: '/my/path'
        expect(described_class.default_file).to eq('/my/path/pry/pry_history')
      end
    end
  end

  describe '#push' do
    it "does not record duplicated lines" do
      Pry.history << '3'
      Pry.history << '_ += 1'
      Pry.history << '_ += 1'
      expect(Pry.history.to_a.grep('_ += 1').count).to eq 1
    end

    it "does not record lines that contain a NULL byte" do
      c = Pry.history.to_a.size
      Pry.history << "a\0b"
      expect(Pry.history.to_a.size).to eq c
    end

    it "does not record empty lines" do
      c = Pry.history.to_a.size
      Pry.history << ''
      expect(Pry.history.to_a.size).to eq c
    end
  end

  describe "#clear" do
    before do
      @old_file = Pry.config.history_file
      @hist_file_path = File.expand_path('spec/fixtures/pry_history')
      Pry.config.history_file = @hist_file_path
      Pry.history.clear
      Pry.load_history
    end

    after do
      Pry.config.history_file = @old_file
    end

    it "clears this session's history" do
      expect(Pry.history.to_a.size).to be > 0
      Pry.history.clear
      expect(Pry.history.to_a.size).to eq 0
      expect(Pry.history.original_lines).to eq 0
    end

    it "doesn't affect the contents of the history file" do
      expect(Pry.history.to_a.size).to eq 3
      Pry.history.clear

      File.open(@hist_file_path, 'r') do |fh|
        file = fh.to_a

        expect(file.length).to eq 3
        expect(file.any? { |a| a =~ /athos/ }).to eq true
      end
    end
  end

  describe "#history_line_count" do
    it "counts entries in history" do
      Pry.history.clear
      saved_history = "olgierd\ngustlik\njanek\ngrzes\ntomek\n"
      Pry.history.loader = proc do |&blk|
        saved_history.lines.each { |l| blk.call(l) }
      end
      Pry.load_history

      expect(Pry.history.history_line_count).to eq 5
    end
  end

  describe "#session_line_count" do
    it "returns the number of lines in history from just this session" do
      Pry.history << 'you?'
      Pry.history << 'you are so precious'
      expect(Pry.history.session_line_count).to eq 2
    end
  end

  describe ".load_history" do
    it "reads the contents of the file" do
      expect(Pry.history.to_a[-2..-1]).to eq %w[2 3]
    end
  end

  describe "saving to a file" do
    before do
      @histfile = Tempfile.new(%w[pryhistory txt])
      @history = Pry::History.new(file_path: @histfile.path)
      Pry.config.history_save = true
    end

    after do
      @histfile.close(true)
      Pry.config.history_save = false
    end

    it "saves lines to a file as they are written" do
      @history.push "5"
      expect(File.read(@histfile.path)).to eq "5\n"
    end

    it "interleaves lines from many places" do
      @history.push "5"
      File.open(@histfile.path, 'a') { |f| f.puts "6" }
      @history.push "7"

      expect(File.read(@histfile.path)).to eq "5\n6\n7\n"
    end

    it "should not write histignore words to the history file" do
      Pry.config.history_ignorelist = ["ls", /hist*/, 'exit']
      @history.push "ls"
      @history.push "hist"
      @history.push "kakaroto"
      @history.push "exit"

      expect(File.open(@histfile.path).entries.size).to eq 1
      expect(IO.readlines(@histfile.path).first).to eq "kakaroto\n"
    end
  end

  describe "expanding the history file path" do
    before { Pry.config.history_save = true  }
    after  { Pry.config.history_save = false }

    it "recognizes ~ (#1262)" do
      # This is a pretty dumb way of testing this, but at least it shouldn't
      # succeed spuriously.
      history = Pry::History.new(file_path: '~/test_history')
      error = Class.new(RuntimeError)

      expect(File).to receive(:open)
        .with(File.join(ENV['HOME'].to_s, "/test_history"), 'a', 0o600)
        .and_raise(error)

      expect { history.push 'a line' }.to raise_error error
    end
  end

  describe "file io errors" do
    let(:history) { Pry::History.new(file_path: file_path) }
    let(:file_path) { Tempfile.new("pry_history_spec").path }

    [Errno::EACCES, Errno::ENOENT].each do |error_class|
      it "handles #{error_class} failure to read from history" do
        expect(File).to receive(:foreach).and_raise(error_class)
        expect(history).to receive(:warn).with(/Unable to read history file:/)
        expect { history.load }.to_not raise_error
      end

      it "handles #{error_class} failure to write history" do
        Pry.config.history_save = true
        expect(File).to receive(:open).with(file_path, "a", 0o600).and_raise(error_class)
        expect(history).to receive(:warn).with(/Unable to write history file:/)
        expect { history.push("anything") }.to_not raise_error
      end
    end
  end
end
