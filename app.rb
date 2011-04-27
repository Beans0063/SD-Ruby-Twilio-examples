require 'rubygems'
require 'sinatra'
require 'net/http'
require 'logger'
require 'dm-core'

# if ENV['RACK_ENV']=="development"
#   log = Logger.new('log.txt')
# else
#   logger = Logger.new(STDOUT)
# end
logger = Logger.new(STDOUT)

if ENV['RACK_ENV']=="development"
  DataMapper.setup(:default, 'mysql://localhost/unhurler_development')
else
  DataMapper.setup(:default, 'mysql://ape.beanserver.net/unhurler_production')
end

class Endpoint
  include DataMapper::Resource
  property :id,         Serial    # An auto-increment integer key
  property :url,      String
  property :code,      String
  property :domain,      String
  property :path,      String
  property :scheme,      String
end
class ProxiedRequest
  include DataMapper::Resource
  property :id,         Serial    # An auto-increment integer key
  property :req_data,     Text
  property :req_request,     Text
  property :req_method, Text
  property :req_headers,     Text
  property :req_body,     Text
  property :req_time,     DateTime
  property :resp_time,     DateTime
  property :created_at,   DateTime
  property :endpoint_id,     Serial
  property :resp_headers, Text
  property :resp_body, Text
  property :resp_status, Text
  property :resp_response, Text
end

DataMapper.finalize

def get_or_post(path, opts={}, &block)
  get(path, opts, &block)
  post(path, opts, &block)
end

def make_header_hash(endpoint)
#	excludeHeaders = Set.new [ 'HTTP_HOST', 'HTTP_X_HEROKU', 'HTTP_X_REQUEST_START', 'HTTP_X_FORWARDED_FOR', 'HTTP_X_VARNISH' ,'HTTP_X_REAL_IP']
  excludeHeaders=[]
  result={}
	headers = env.select {|k,v| k.start_with? 'HTTP_' and !k.start_with?  'HTTP_X_HEROKU' and !excludeHeaders.include? k}
	headers = headers.map do |k,v|
		k = k[5..-1]
		arr = k.split("_")
		arr = arr.collect { |a| a.capitalize }
#		k = arr.join("-")
#		"-H \"#{k}: #{v}\""
		"#{k}: #{v}"
		v=unhurler if k=="USER-AGENT"
		v=endpoint.domain if k=="HOST"
		result[k]=v
	end
	
	result
end


def get_endpoint
  begin
    code=request.path_info[1,request.path_info.length]
    endpoint = Endpoint.first(:code=>code)
    if endpoint==nil
      #endpoint = Endpoint.first(:code=>req.cookies.first.value)
    end
    endpoint
  rescue
    nil
  end
end


get_or_post '*' do
#	log.debug request.path_info
  endpoint=get_endpoint
  raise Sinatra::NotFound if endpoint.nil?

  headers=make_header_hash(endpoint)  
	logger.debug headers.inspect
	
	if request.request_method=="GET"
    req = Net::HTTP::Get.new(endpoint.path, headers)
  else
    req = Net::HTTP::Get.new(endpoint.path, headers)
    #req.set_form_data({'from'=>'2005-01-01', 'to'=>'2005-03-31'}, ';')
  end
   #req.body_stream = request.body
   #req.content_type = request.content_type
   #req.content_length = request.content_length || 0
   @host=endpoint.domain
   @port="80"
   http = Net::HTTP.new(@host, @port)
   res = http.request(req)

   # status, headers, body = @app.call(env)
   # headers = Utils::HeaderHash.new(headers)
   # headers['Content-Type'] ||= @content_type
   # foo=[status, headers, body]
  
  #"Hello: #{env.keys.inspect}"
  raw = request.env["rack.input"].read
  headers = Rack::Utils::HeaderHash.new(env.keys) 
#  log.debug headers.inspect
#  log.debug env.inspect
#  log.debug raw
  #{}"<Response><Say>Bye</Say></Response>"
  res.body
end

not_found do
  "<h1>404 Not Found</h1><pre>Forwarding destination could not be found</pre>"
end