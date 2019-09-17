require 'net/http'
require 'uri'
require 'json'
require 'nokogiri'

module HybridPlatformsConductor

  # Gives helpers to use Confluence API
  # Use the following environment variables to get Confluence user name and password: hpc_confluence_user, hpc_confluence_password
  module Confluence

    # Return a Confluence storage format content from a page ID
    #
    # Parameters::
    # * *page_id* (String): Confluence page ID
    # Result::
    # * Nokogiri::HTML: Storage format content, as a Nokogiri object
    def confluence_page_storage_format(page_id)
      Nokogiri::HTML(call_confluence_api("plugins/viewstorage/viewpagestorage.action?pageId=#{page_id}").body)
    end

    # Return some info of a given page ID
    #
    # Parameters::
    # * *page_id* (String): Confluence page ID
    # Result::
    # * Hash: Page information, as returned by the Confluence API
    def confluence_page_info(page_id)
      JSON.parse(call_confluence_api("rest/api/content/#{page_id}").body)
    end

    # Update a Confluence page to a new content.
    #
    # Parameters::
    # * *page_id* (String): Confluence page ID
    # * *content* (String): New content
    # * *version* (String or nil): New version, or nil to automatically increase last existing version [default: nil]
    def confluence_page_update(page_id, content, version: nil)
      info = confluence_page_info(page_id)
      version = info['version']['number'] + 1 if version.nil?
      log_debug "Update Confluence page #{page_id}..."
      call_confluence_api("rest/api/content/#{page_id}", :put) do |request|
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
    # * *confluence_url* (String): The confluence URL
    # * *http_method* (Symbol): HTTP method to be used to create the request [default = :get]
    # * Proc: Optional code called to alter the request
    #   * Parameters::
    #     * *request* (Net::HTTPRequest): The request
    # Result::
    # * Net::HTTPResponse: The corresponding response
    def call_confluence_api(confluence_url, http_method = :get)
      response = nil
      page_url = URI.parse("https://www.site.my_company.net/confluence/#{confluence_url}")
      Net::HTTP.start(page_url.host, page_url.port, use_ssl: true) do |http|
        request = Net::HTTP.const_get(http_method.to_s.capitalize.to_sym).new(page_url.request_uri)
        request.basic_auth ENV['hpc_confluence_user'], ENV['hpc_confluence_password']
        yield request if block_given?
        response = http.request(request)
        raise "Confluence page API request on #{page_url} returned an error: #{response.code}\n#{response.body}\n===== Request body =====\n#{request.body}" unless response.is_a?(Net::HTTPSuccess)
      end
      response
    end

  end

end
