require 'rubygems'
require 'sinatra'
require 'twilio-ruby'
require 'dm-core'
require 'pusher'

Pusher.app_id = 'xxxxx'
Pusher.key    = 'xxxxxx'
Pusher.secret = 'xxxxxx'

DataMapper::Logger.new($stdout, :debug) if ENV['RACK_ENV']=="development"
DataMapper.setup(:default, 'mysql://localhost/sd_ruby')

APP_NUMBER="(858) 333-8623"

class Sms
  include DataMapper::Resource
  property :id,         Serial    # An auto-increment integer key
  property :Sms_sid, String
  property :From,   String
  property :To,     String
  property :Body,    String
end

class Call
  include DataMapper::Resource
  property :id,         Serial    # An auto-increment integer key
  property :CallSid,  String
  property :From,     String
  property :To,       String
  property :Direction, String
end

DataMapper.finalize

post '/sms_incoming' do
  sms=save_sms
  if sms.From.index("+1858")
    message_from="coastal San Diego"
  elsif sms.From.index("+1619")
    message_from="central San Diego"
  elsif sms.From.index("+1760")
    message_from="north County San Diego"
  else
    message_from="outside San Diego"
  end

  Pusher['sms_channel'].trigger('incoming_sms', {
    :greeting => "<p>#{sms.From[8,11]} says #{sms.Body}</p>"
  })

  content_type :xml
  '<?xml version="1.0" encoding="UTF-8"?>
  <Response>
    <Sms>Greetings.  It looks like youre from ' + message_from + '</Sms>
  </Response>'
end

def save_sms
  sms = Sms.new(:Sms_sid=>params[:SmsSid], :From=>params[:From], :To=>params[:To], :Body=>params[:Body])
  sms.save
  sms
end

get '/' do
"  <html><body><script src=""http://js.pusherapp.com/1.8/pusher.min.js""></script>
  <script type=""text/javascript"">
    var pusher = new Pusher('" + Pusher.key + "'); // uses your API KEY
    var channel = pusher.subscribe('sms_channel');
    channel.bind('incoming_sms', function(data) {
      document.getElementById('messages').innerHTML +=data.greeting;    
    });
  </script>
  <h1>SD Ruby SMS messages " + APP_NUMBER + "</h1>
  <div id='messages'></div>
  </body></html>"
end

get '/raffle' do
  numbers = Sms.all(:fields => [:From], :unique => true, :order => [:From]).sort_by { rand }
  winner=numbers.shift.From
  send_sms(winner,"Congrats - you're the big winner!")
  losers=numbers.each.collect{|n| "<li>#{n.From[8,11]}</li>"}
  "<h2>And the big winner is:</h2> <h1>#{winner[8,11]}!</h1>
  <h2>Sorry you didn't win:</h2>
  #{losers}"
end

def send_sms(to,body,from=APP_NUMBER)
  require 'twilio-ruby'
  @account_sid = 'ACxxxxx'
  @auth_token = 'xxxxxx'
  @client = Twilio::REST::Client.new(@account_sid, @auth_token)
  @account = @client.accounts.get(@account_sid)
  @account.sms.messages.create(:From => from, :To => to, :Body => body)
end