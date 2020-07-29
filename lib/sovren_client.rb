require 'uri'
require 'net/http'
require 'net/https'
require 'base64'
require 'json'

class SovrenClient
    attr_reader :endpoint, :account_id, :service_key, :revision_date

    def initialize(options={})
      @endpoint = options[:endpoint]
      @account_id = options[:account_id]
      @service_key = options[:service_key]
      @revision_date = options[:revision_date]
      @headers = {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
        'Sovren-AccountId' => options[:account_id],
        'Sovren-ServiceKey' =>  options[:service_key]
      }
    end

    def parse(file)
        #revision_date = File.mtime(@filepath).to_s[0,10]
        # Encode the bytes to base64
        data = {
        "DocumentAsBase64String" => Base64.encode64(file)
        #other options here (see http://documentation.sovren.com/API/Rest/Parsing)
        }.to_json
        uri = URI.parse(@endpoint)
        https = Net::HTTP.new(uri.host,uri.port)
        https.use_ssl = true
        req = Net::HTTP::Post.new(uri.path, initheader = @headers)
        req.body = data
        res = https.request(req)
        # Parse the response body into an object
        respObj = JSON.parse(res.body)
        # Parse the ParsedDocument string into an object (for response properties and types, see http://documentation.sovren.com/API/Rest/Parsing)

        Resume.parse(JSON.parse(respObj["Value"]["ParsedDocument"]))
    end
end
