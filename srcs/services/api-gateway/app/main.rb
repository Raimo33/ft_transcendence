require 'sinatra'

get '/api' do
  'API Gateway is running'
end

post '/api' do
  'POST request received'
end
