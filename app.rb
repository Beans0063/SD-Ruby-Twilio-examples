require 'rubygems'
require 'sinatra'
require 'net/http'
require 'logger'
require 'dm-core'
require 'json'
require 'pusher'

# if ENV['RACK_ENV']=="development"
#   log = Logger.new('log.txt')
# else
#   logger = Logger.new(STDOUT)
# end

#pusher config
#DataMapper::Logger.new($stdout, :debug)

if ENV['RACK_ENV']=="development"
  Pusher.app_id = '5259'
  Pusher.key    = '1a7b621bc0e6e22a74cb'
  Pusher.secret = 'a6b181b9c01c00db9a85'
else
  Pusher.app_id = '5258'
  Pusher.key    = '3138e29133e9f140017c'
  Pusher.secret = '80498a2d9b158a04a450'
end

logger = Logger.new(STDOUT)

if ENV['RACK_ENV']=="development"
  DataMapper.setup(:default, 'mysql://localhost/unhurler_development')
else
  DataMapper.setup(:default,  ENV['DATABASE_URL'] )
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
	#result["Set-Cookie"]="unhurler_code=#{endpoint.code}"
	#resp.gsub!(/Server: .*?\r\n/, "Set-Cookie: unhurler_code=#{endpoint.code}\r\n")
  
	result
end


def get_endpoint
  code=request.path_info[1,request.path_info.length]
  #logger.debug "Code: #{code}"
  endpoint = Endpoint.first(:code=>code)
  if endpoint==nil
    endpoint = Endpoint.first(:code=>request.cookies["unhurler_code"])
  end
  endpoint
end

def log_req(headers,endpoint,path_to_request)
  p = ProxiedRequest.new(:req_data=>path_to_request, :req_request=>"", :req_method=>request.request_method, :req_headers=>headers.to_json, :req_body=>request.env["rack.input"].read, :endpoint_id=>endpoint.id, :req_time=>Time.now,  :created_at=>Time.now)
  p.save
  p.id
end

def log_resp(resp,req_id)
  p=ProxiedRequest.first(:id=>req_id)
#  p.attributes = {:resp_headers=>resp.to_hash.to_json,:resp_status=>resp.code,:resp_body=>resp.body, :resp_time=>Time.now, :resp_response=>"#{resp.code} #{res.message}"}
  if resp.to_hash.has_key?("content-type") && resp.to_hash["content-type"].index("audio")
    log_body=""
  else
    log_body=resp.body
  end
  begin
    p.attributes = {:resp_headers=>resp.to_hash.to_json,:resp_status=>resp.code,:resp_body=>log_body, :resp_time=>Time.now, :resp_response=>"#{resp.code} #{resp.message}"}
    result = p.save!
  rescue
    begin
      log_body=""
      p.attributes = {:resp_headers=>resp.to_hash.to_json,:resp_status=>resp.code,:resp_body=>log_body, :resp_time=>Time.now, :resp_response=>"#{resp.code} #{resp.message}"}
      result = p.save!
    rescue
    end
  end
end

def request_body
  request.env["rack.input"].read
end

get_or_post '*' do
  #	log.debug request.path_info
  #logger.debug "cookies: #{request.cookies}"
#  code=request.path_info[1,request.path_info.length]
#  logger.debug  code
#  endpoint = Endpoint.first(:code=>code)
 
  endpoint=get_endpoint
  logger.debug "endpoint: #{endpoint.inspect}"
  raise Sinatra::NotFound if endpoint.nil?

  headers=make_header_hash(endpoint)  
	
	code=request.path_info[1,request.path_info.length]
	if code==endpoint.code
	  path_to_request=endpoint.path
  else
	  path_to_request=request.path_info
  end
	req_id=log_req(headers,endpoint,path_to_request)
	
	if request.request_method=="GET"
    req = Net::HTTP::Get.new(path_to_request, headers)
  else
#    form_data=Rack::Utils.parse_query(request_body)
#    form_data=request.body
    form_data=request.POST
    #logger.debug("form_data: #{form_data}")
    req = Net::HTTP::Post.new(path_to_request, headers)
    req.set_form_data(form_data)
  end

   #req.body_stream = request.body
   #req.content_type = request.content_type
   #req.content_length = request.content_length || 0
   @host=endpoint.domain
   @port="80"
   http = Net::HTTP.new(@host, @port)
   resp = http.request(req)
   log_resp(resp,req_id)
   #logger.debug "res: #{res.to_hash}"
   # status, headers, body = @app.call(env)
   # headers = Utils::HeaderHash.new(headers)
   # headers['Content-Type'] ||= @content_type
   # foo=[status, headers, body]
  
  #"Hello: #{env.keys.inspect}"
  #raw = request.env["rack.input"].read
  #headers = Rack::Utils::HeaderHash.new(env.keys) 
#  log.debug headers.inspect
#  log.debug env.inspect
#  log.debug raw
  #{}"<Response><Say>Bye</Say></Response>"
  
  resp.to_hash.each do |k,v|
    headers k=>v if !k.index("transfer-encoding")
  end
  Pusher["e#{endpoint.id}"].trigger('req', { :req => req_id })
  
  headers "Set-Cookie"=>"unhurler_code=#{endpoint.code}" if request.user_agent.index("TwilioProxy")
  logger.debug(resp.body)
  resp.body
end

not_found do
  "<h1>404 Not Found</h1><pre>Forwarding destination could not be found</pre>"
end

# 
# get '/pushertest' do
# "  <html><body><script src=""http://js.pusherapp.com/1.8/pusher.min.js""></script>
#   <script type=""text/javascript"">
#     var pusher = new Pusher('" + Pusher.key + "'); // uses your API KEY
#     var channel = pusher.subscribe('test_channel');
#     channel.bind('greet', function(data) {
#       alert(data.greeting);
#     });
#   </script>
#   PUSH</body></html>"
# end
# 
# get '/pushertestmessage' do
#   Pusher['test_channel'].trigger('greet', {
#     :greeting => "Hello there!"
#   })
#   "PP"
# end