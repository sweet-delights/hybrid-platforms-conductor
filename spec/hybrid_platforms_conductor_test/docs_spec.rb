describe 'Documentation' do

  it 'makes sure all Markdown links are valid' do
    check_stdout = `bundle exec tools/check_md README.md #{Dir.glob('docs/**/*.md').join(' ')}`.split("\n")
    summary_idx = check_stdout.index { |line| line =~ /^\d+ errors:$/ }
    expect(summary_idx).not_to be_nil, "Could not parse check output: #{check_stdout.join("\n")}"
    expect(check_stdout[summary_idx]).to eq('0 errors:'), "Invalid links found: #{check_stdout[summary_idx..].join("\n")}"
  end

end
