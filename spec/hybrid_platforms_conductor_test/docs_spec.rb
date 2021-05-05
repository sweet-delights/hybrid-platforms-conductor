describe 'Documentation' do

  it 'makes sure all Markdown links are valid' do
    check_stdout = `bundle exec ruby -w tools/check_md README.md #{Dir.glob('docs/**/*.md').join(' ')}`.split("\n")
    summary_idx = check_stdout.index { |line| line =~ /^\d+ errors:$/ }
    expect(summary_idx).not_to eq(nil), "Could not parse check output: #{check_stdout.join("\n")}"
    expect(check_stdout[summary_idx]).to eq('0 errors:'), "Invalid links found: #{check_stdout[summary_idx..-1].join("\n")}"
  end

end
