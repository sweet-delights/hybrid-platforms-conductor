require 'net/http'
require 'uri'
require 'json'
require 'nokogiri'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/netrc'

module HybridPlatformsConductor

  # Object used to access Confluence API
  class Confluence

    include LoggerHelpers

    # Provide a Confluence connector, and make sure the password is being cleaned when exiting.
    #
    # Parameters::
    # * *confluence_url* (String): The Confluence URL
    # * *logger* (Logger): Logger to be used
    # * *logger_stderr* (Logger): Logger to be used for stderr
    # * *user_name* (String): Confluence user name to be used when querying the API [default: Read from .netrc]
    # * *password* (String): Confluence password to be used when querying the API [default: Read from .netrc]
    # * Proc: Code called with the Confluence instance.
    #   * *confluence* (Confluence): The Confluence instance to use.
    def self.with_confluence(confluence_url, logger, logger_stderr, user_name: nil, password: nil)
      if user_name.nil? || password.nil?
        # Read credentials from netrc
        Netrc.with_netrc_for(URI.parse(confluence_url).host.downcase) do |netrc_user, netrc_password|
          # Clone them as exiting the block will erase them
          user_name ||= netrc_user.dup
          password ||= netrc_password.dup
        end
      end
      confluence = Confluence.new(confluence_url, user_name, password, logger: logger, logger_stderr: logger_stderr)
      begin
        yield confluence
      ensure
        confluence.clear_password
      end
    end

    # The Confluence URL
    # String
    attr_reader :confluence_url

    # Constructor
    #
    # Parameters::
    # * *confluence_url* (String): The Confluence URL
    # * *confluence_user_name* (String): Confluence user name to be used when querying the API
    # * *confluence_password* (String): Confluence password to be used when querying the API
    # * *logger* (Logger): Logger to be used [default = Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
    def initialize(confluence_url, confluence_user_name, confluence_password, logger: Logger.new(STDOUT), logger_stderr: Logger.new(STDERR))
      @confluence_url = confluence_url
      @confluence_user_name = confluence_user_name
      @confluence_password = confluence_password
      @logger = logger
      @logger_stderr = logger_stderr
    end

    # Provide a helper to clear password from memory for security.
    # To be used when the client knows it won't use the API anymore.
    def clear_password
      @confluence_password.replace('gotyou!' * 100) unless @confluence_password.nil?
      GC.start
    end

    # Return a Confluence storage format content from a page ID
    #
    # Parameters::
    # * *page_id* (String): Confluence page ID
    # Result::
    # * Nokogiri::HTML: Storage format content, as a Nokogiri object
    def page_storage_format(page_id)
      Nokogiri::HTML(call_api("plugins/viewstorage/viewpagestorage.action?pageId=#{page_id}").body)
    end

    # Return some info of a given page ID
    #
    # Parameters::
    # * *page_id* (String): Confluence page ID
    # Result::
    # * Hash: Page information, as returned by the Confluence API
    def page_info(page_id)
      JSON.parse(call_api("rest/api/content/#{page_id}").body)
    end

    # Update a Confluence page to a new content.
    #
    # Parameters::
    # * *page_id* (String): Confluence page ID
    # * *content* (String): New content
    # * *version* (String or nil): New version, or nil to automatically increase last existing version [default: nil]
    def update_page(page_id, content, version: nil)
      info = page_info(page_id)
      version = info['version']['number'] + 1 if version.nil?
      log_debug "Update Confluence page #{page_id}..."
      call_api("rest/api/content/#{page_id}", :put) do |request|
        request['Content-Type'] = 'application/json'
        request.body = {
          type: 'page',
          title: info['title'],
          body: {
            storage: {
              value: content,
              representation: 'storage'
            }
          },
          version: { number: version }
        }.to_json
      end
    end

    private

    # Call the Confluence API for a given URL and HTTP verb.
    # Provide a simple way to tweak the request with an optional proc.
    # Automatically handles authentication, base URL and error handling.
    #
    # Parameters::
    # * *api_path* (String): The API path to query
    # * *http_method* (Symbol): HTTP method to be used to create the request [default = :get]
    # * Proc: Optional code called to alter the request
    #   * Parameters::
    #     * *request* (Net::HTTPRequest): The request
    # Result::
    # * Net::HTTPResponse: The corresponding response
    def call_api(api_path, http_method = :get)
      response = nil
      page_url = URI.parse("#{@confluence_url}/#{api_path}")
      Net::HTTP.start(page_url.host, page_url.port, use_ssl: true) do |http|
        request = Net::HTTP.const_get(http_method.to_s.capitalize.to_sym).new(page_url.request_uri)
        request.basic_auth @confluence_user_name, @confluence_password
        yield request if block_given?
        response = http.request(request)
        raise "Confluence page API request on #{page_url} returned an error: #{response.code}\n#{response.body}\n===== Request body =====\n#{request.body}" unless response.is_a?(Net::HTTPSuccess)
      end
      response
    end

  end

end
