#!/usr/bin/ruby -w
require 'inotify'
require 'socket'
include Socket::Constants

# Setup a server
def setup_server(ip, port)
  socket = Socket.new(AF_INET, SOCK_STREAM, 0)
  sockaddr = Socket.pack_sockaddr_in(port, ip)
  puts "Waiting for a connection on " + sockaddr.inspect
  socket.bind(sockaddr)
  socket.listen(5)
  client, client_sockaddr = socket.accept

  # Let's wait for someone to connect
  read = ''
  while data = client.recvfrom(1)
    read += data.join
    if read == 'START'
      client.puts "ACK"

      get_forked(client)
      read = ''
    end
  end
end

def get_forked(client)
  setup_listener(client)
end

def setup_listener(client)
  file = ARGV.first

  mon = Inotify.new
  mon.add_watch(file, Inotify::MODIFY)
  puts client.inspect
  mon.each_event do |event|
    client.puts "$$$"
  end
end

setup_server('0.0.0.0', 1337)
