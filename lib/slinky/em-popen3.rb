require 'rubygems'
require 'eventmachine'

if RUBY_VERSION < "1.8.7"
  def __method__
    caller = /`(.*)'/
    Kernel.caller.first.split(caller).last.to_sym
  end
end

def log *message
  p [Time.now, *message]
end

module EventMachine
  def self.popen3(*args)
    new_stderr = $stderr.dup
    rd, wr = IO::pipe
    $stderr.reopen wr
    connection = EM.popen(*args)
    $stderr.reopen new_stderr
    EM.attach rd, Popen3StderrHandler, connection
    connection
  end
  
  class Popen3StderrHandler < EventMachine::Connection
    def initialize(connection)
      @connection = connection
    end
    
    def receive_data(data)
      @connection.receive_stderr(data)
    end
  end  
end

class ProcessHandler < EventMachine::Connection  
  def initialize cb
    @cb = cb
    @stdout = []
    @stderr = []
  end

  def receive_data data 
    @stdout << data
  end

  def receive_stderr data 
    @stderr << data
  end
  
  def unbind
    @cb.call @stdout.join(''), @stderr.join(''), get_status if @cb
  end
end

def EventMachine::system3 cmd, *args, &cb
  cb ||= args.pop if args.last.is_a? Proc
  init = args.pop if args.last.is_a? Proc

  # merge remaining arguments into the command
  cmd = ([cmd] + args.map{|a|a.to_s.dump}).join(' ')

  EM.get_subprocess_pid(EM.popen3(cmd, ProcessHandler, cb) do |c|
                          init[c] if init
                        end.signature)
end
