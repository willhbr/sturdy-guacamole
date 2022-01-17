require "http/server"

class DelayHandler
  include HTTP::Handler

  def call(context)
    puts "serving #{context.request.path}"
    sleep 1.second
    call_next context
    context.response.headers.delete("Etag")
    context.response.headers.delete("Last-Modified")
    puts context.response.headers
  end
end

server = HTTP::Server.new [DelayHandler.new, HTTP::StaticFileHandler.new(ARGV[0])]

server.bind_tcp "0", 4001
puts "listening..."
server.listen
