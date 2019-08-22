describe 'executables\' Reports Handler options' do

  # Setup a platform for tests
  #
  # Parameters::
  # * Proc: Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_reports_handler_options
    with_test_platform do |repository|
      register_report_plugins(test_reports_handler, report_format: HybridPlatformsConductorTest::ReportPlugin)
      yield repository
    end
  end

  it 'uses a given format' do
    with_test_platform_for_reports_handler_options do
      expect(test_reports_handler).to receive(:produce_report_for).with([{ all: true }]) do
        expect(test_reports_handler.format).to eq :report_format
        {}
      end
      exit_code, stdout, stderr = run 'report', '--format', 'report_format'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'fails to use an unknown format' do
    with_test_platform_for_reports_handler_options do
      expect { run 'report', '--format', 'unknown_format' }.to raise_error(RuntimeError, 'Unknown format: unknown_format')
    end
  end

  it 'uses a given locale' do
    with_test_platform_for_reports_handler_options do
      expect(test_reports_handler).to receive(:produce_report_for).with([{ all: true }]) do
        expect(test_reports_handler.locale).to eq :fr
        {}
      end
      exit_code, stdout, stderr = run 'report', '--format', 'report_format', '--locale', 'fr'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'fails to use an unknown locale' do
    with_test_platform_for_reports_handler_options do
      expect { run 'report', '--format', 'report_format', '--locale', 'unknown_locale' }.to raise_error(RuntimeError, 'Unknown locale for format report_format: unknown_locale')
    end
  end

end
