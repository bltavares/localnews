require "net/http"

desc "Ping app"
task :ping do
  uri = URI(ENV['PING_URL'])
  Net::HTTP.get_response(uri)
end
