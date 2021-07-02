require 'json'
require 'net/http'
require 'nokogiri'
require 'uri'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/credentials'

module HybridPlatformsConductor

  # Mixin used to access Confluence API
  module Confluence

    include Credentials

    # Provide a Confluence connector, and make sure the password is being cleaned when exiting.
    #
    # Parameters::
    # * *confluence_url* (String): The Confluence URL
    # * Proc: Code called with the Confluence instance.
    #   * *confluence* (ConfluenceApi): The Confluence instance to use.
    def with_confluence(confluence_url)
      with_credentials_for(:confluence, resource: confluence_url) do |confluence_user, confluence_password|
        yield ConfluenceApi.new(confluence_url, confluence_user, confluence_password, logger: @logger, logger_stderr: @logger_stderr)
      end
    end

    # Provide an API access on Confluence
    class ConfluenceApi

      include LoggerHelpers

      # Constructor
      #
      # Parameters::
      # * *confluence_url* (String): The Confluence URL
      # * *confluence_user_name* (String): Confluence user name to be used when querying the API
      # * *confluence_password* (SecretString): Confluence password to be used when querying the API
      # * *logger* (Logger): Logger to be used [default = Logger.new(STDOUT)]
      # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
      def initialize(confluence_url, confluence_user_name, confluence_password, logger: Logger.new($stdout), logger_stderr: Logger.new($stderr))
        init_loggers(logger, logger_stderr)
        @confluence_url = confluence_url
        @confluence_user_name = confluence_user_name
        @confluence_password = confluence_password
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
          request.basic_auth @confluence_user_name, @confluence_password&.to_unprotected
          yield request if block_given?
          response = http.request(request)
          raise "Confluence page API request on #{page_url} returned an error: #{response.code}\n#{response.body}\n===== Request body =====\n#{request.body}" unless response.is_a?(Net::HTTPSuccess)
        end
        response
      end

    end

  end

end
