#!/usr/bin/ruby
require 'socket'
require 'inotify'

class Preforker 
    attr_reader (:child_count)
    
    def initialize(prefork, max_clients_per_child, port, client_handler)
        @prefork = prefork
        @max_clients_per_child = max_clients_per_child
        @port = port
        @child_count = 0
        
        @reaper = proc {
            trap('CHLD', @reaper)
            pid = Process.wait
            @child_count -= 1
        }
        
        @huntsman = proc {
            trap('CHLD', 'IGNORE')
            trap('INT', 'IGNORE')
            Process.kill('INT', 0)
            exit
        }
        
        @client_handler=client_handler
    end
    
    def child_handler
        trap('INT', 'EXIT')
        @client_handler.setUp
        # wish: sigprocmask UNblock SIGINT
        @max_clients_per_child.times {
            client = @server.accept or break
            @client_handler.handle_request(client)
            client.close
        }
        @client_handler.tearDown
    end
    
    def make_new_child
        # wish: sigprocmask block SIGINT
        @child_count += 1
        pid = fork do
            child_handler
        end
        # wish: sigprocmask UNblock SIGINT
    end
    
    def run
        @server = TCPserver.open(@port)
        trap('CHLD', @reaper)
        trap('INT', @huntsman)
        loop {
            (@prefork - @child_count).times { |i|
                make_new_child
            }
            sleep 0.1
        }
    end
end

class ClientHandler
    @monitor
    def setUp
    	file = ARGV.first
  		@monitor = Inotify.new
  		@monitor.add_watch(file, Inotify::MODIFY)
    end
    
    def tearDown
   		@monitor.close 
	end
    
    def handle_request(client)
  		@monitor.each_event do |event|
    		client.puts "$$$"
  		end
    end
end

server = Preforker.new(5, 100, 1337, ClientHandler.new)
server.run
