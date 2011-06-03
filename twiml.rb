require 'rubygems'
require 'sinatra'

get '/say' do
  content_type :xml
  '<?xml version="1.0" encoding="UTF-8"?>
  <Response>
  <Say>Hello San Diego Ruby</Say>
  </Response>'
end

get '/play' do
  content_type :xml
  '<?xml version="1.0" encoding="UTF-8"?>
  <Response>
  <Say>Hello San Diego Ruby</Say>
  <Play>http://dl.dropbox.com/u/11489766/epic_sax.mp3</Play>
  </Response>'
end

get '/gather' do
  content_type :xml
  '<?xml version="1.0" encoding="UTF-8"?>
  <Response>
  <Say voice="woman">Hello San Diego Ruby</Say>
  <Gather action="/gather_reply" method="GET" numDigits="1">
    <Say voice="woman">How many years have you been working in Ruby?</Say>
  </Gather>
  </Response>'
end

get '/gather_reply' do
  content_type :xml
  '<?xml version="1.0" encoding="UTF-8"?>
  <Response>
  <Say voice="woman">I hear youve been a rubyist for ' + params[:Digits] + ' years.  Thats fantastic!.</Say>
  </Response>'
end
