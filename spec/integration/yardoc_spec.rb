require_relative "../helper"

RSpec.describe "YARD documentation generation", only_ruby: [:mri_19, :mri_23] do
  let(:project_root) do
    File.expand_path File.join(__FILE__, '..', '..', '..')
  end

  let(:yard_dir) do
    File.expand_path(File.join(__FILE__, "..", "..", "..", ".yardoc"))
  end

  before(:example) { FileUtils.rm_rf yard_dir }
  after(:example) { FileUtils.rm_rf yard_dir }

  specify "no warnings are generated" do
    warn "[notice]: Generating documentation. Please wait."
    Dir.chdir project_root do
      `ruby -S yardoc`.each_line do |line|
        expect(line).to_not match(/\A\[warn\]:/), line
      end
    end
  end

  specify "yardoc exits with a successful status code" do
    warn "[notice]: Generating documentation. Please wait."
    Dir.chdir project_root { `ruby -S yardoc` }
    expect($?.exitstatus).to eq(0), "yardoc exited with #{$?.exitstatus}"
  end
end
