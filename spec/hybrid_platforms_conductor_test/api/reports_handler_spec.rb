describe HybridPlatformsConductor::ReportsHandler do

  # Setup a test platform for our reports testing
  #
  # Parameters::
  # * Proc: Code called when platform is setup
  def with_test_platform_for_reports_test
    with_test_platform({ nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} } }) do
      register_report_plugins(test_reports_handler, report: HybridPlatformsConductorTest::ReportPlugin)
      test_reports_handler.format = :report
      yield
    end
  end

  it 'delivers a simple report on all the inventory' do
    with_test_platform_for_reports_test do
      test_reports_handler.produce_report_for [{ all: true }]
      expect(HybridPlatformsConductorTest::ReportPlugin.generated_reports).to eq ['Report generated for node1, node2, node3 in en']
    end
  end

  it 'delivers a simple report on some nodes only' do
    with_test_platform_for_reports_test do
      test_reports_handler.produce_report_for %w[node1 node3]
      expect(HybridPlatformsConductorTest::ReportPlugin.generated_reports).to eq ['Report generated for node1, node3 in en']
    end
  end

  it 'delivers a simple report with a different locale' do
    with_test_platform_for_reports_test do
      test_reports_handler.locale = :fr
      test_reports_handler.produce_report_for [{ all: true }]
      expect(HybridPlatformsConductorTest::ReportPlugin.generated_reports).to eq ['Report generated for node1, node2, node3 in fr']
    end
  end

  it 'fails when delivering a simple report with an unknown locale' do
    with_test_platform_for_reports_test do
      test_reports_handler.locale = :de
      expect { test_reports_handler.produce_report_for([{ all: true }]) }.to raise_error(RuntimeError, 'Unknown locale for format report: de')
    end
  end

end
