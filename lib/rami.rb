#
# RAMI - Ruby classes for implementing a proxy server/client api for the Asterisk Manager Interface
#
#
# Copyright (c) 2005, Chris Ochs
# All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#    * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright notice,
#       this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#    * Neither the name of Chris Ochs nor the names of its contributors
#       may be used to endorse or promote products derived from this software
#       without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require 'drb'
require 'monitor'
require 'socket'
require 'timeout'

# Rami can be used to write standalone scripts to send commands to the Asterisk manager interface, or you can
# use Drb and Rami::Server to run a Rami proxy server.  You can then connect to the proxy server using Rami::Client and Drb.
# This module was written against Asterisk 1.2-beta1.  There are a few minor changes to some AMI commands
# in Asterisk CVS HEAD.  When 1.2 is released I will update the module accordingly.
module Rami

# The Rami client.
#
# One possible point of confusion about the client is that it takes a server instance as the sole argument to it's new()
# method.  This is because Rami was designed to be used with Drb.  You don't have to use Drb though.
# You can create and start a Server instance via it's run method, then in the same code create your Client instance
# and submit requests to the server. A simple example..
#
# require 'rubygems'
#
# require 'rami'
#
# include Rami
#
# server = Server.new({'host' => 'localhost', 'username' => 'asterisk', 'secret' => 'secret'})
#
# server.run
#
# client = Client.new(server)
#
# client.timeout = 10
#
# puts client.ping
#
# The above code will start the server and login, then execute the ping command and print the results, then exit, disconnecting
# from asterisk.
#
# To connect to a running server using Drb you can create a client instance like this.:
#
# c = DRbObject.new(nil,"druby://localhost:9000")
#
# client = Client.new(c)
#
#
# All Client methods return an array of hashes, or an empty array if no data is available.
#
# Each hash will contain an asterisk response packet.  Note that not all response packets are always returned.  If a response
# packet is necessary for the actual communication with asterisk, but does not in itself have any meaningful content, then
# the packet is droppped.  For example some actions might generate an initial response packet of something like "Response Follows",
# followed by one or more response packets with the actual data, followed by a final response packet which contains "Response Complete".
# In this case the first and last response will not be included in the array of hashes passed to the caller.
#
# I tried to document the things that need it the most. Some things should be fairly evident, such as methods for simple
# commands like Monitor or Ping.
#
# For examples, see example1.rb, example2.rb, and test.rb in the bin directory.
#
# Not all manager commands are currently supported.  This is only because I have not yet had the time to add them.
# I tried to add the most complicated commands first, so adding the remaining commands is fairly simple.
# If there is a command you need let me know and I will make sure it gets included.
# If you want to add your own action command it's fairly simple.  Add a method in Client for
# the new command, and then add a section in the Client::send_action loop to harvest the response.
class Client

  # Number of seconds before a method call will timeout. Default 10.
  attr_writer :timeout

  # Takes one argument, an instance of Server OR a DrbObject pointed at a running Rami server.
  def initialize(client)
    @timeout = 10
    @action_id = Time.now().to_f
    @client = client
  end


  # Closes the socket connection to Asterisk.  If your client was created using a Server instance instead of a DrbObject, then
  # the connection will be left open as long as your client instance is still valid.  If for example you are making calls from
  # a webserver this is bad as you will end up with a lot of open connections to Asterisk.  So make sure to use stop.
  def stop
    @client.stop
  end

  def absolute_timeout(channel=nil,tout=nil)
    increment_action_id
    return @client.send_action({'ActionID' => @action_id, 'Action' => 'AbsoluteTimeout', 'Channel' => channel, 'Timeout' => tout},@timeout)
  end

  def agents
    increment_action_id
    return @client.send_action({'ActionID' => @action_id, 'Action' => 'Agents'},@timeout)
  end

  def change_monitor(channel=nil,file=nil)
    increment_action_id
    return @client.send_action({'ActionID' => @action_id, 'Action' => 'ChangeMonitor', 'Channel' =>channel, 'File' => file},@timeout)
  end

  def command(command)
    increment_action_id
    return @client.send_action({'ActionID' => @action_id, 'Action' => 'Command', 'Command' => command},@timeout)
  end

  def dbput(family,key,val)
    increment_action_id
    return @client.send_action({'ActionID' => @action_id, 'Action' => 'DBPut', 'Family' => family, 'Key' => key, 'Val' => val},@timeout)
  end

  def dbget(family,key)
    increment_action_id
    return @client.send_action({'ActionID' => @action_id, 'Action' => 'DBGet', 'Family' => family, 'Key' => key},@timeout)
  end

  def extension_state(context,exten)
    increment_action_id
    return @client.send_action({'ActionID' => @action_id, 'Action' => 'ExtensionState', 'Context' => context, 'Exten' => exten},@timeout)
  end

  # If called with key and value, searches the state queue for events matching the key and value given.
  # The key is an exact match, the value is a regex.  You can also call find_events with key=any, which will match
  # any entry with the given value
  #
  # The returned results are deleted from the queue.  See Server for more information on the queue structure.
  def find_events(key=nil,value=nil)
    return @client.find_events(key,value)
  end

  # Get all events from the state queue.  The returned results are deleted from the queue.
  # See Server for more information on the queue structure.
  def get_events
    return @client.get_events
  end

  def getvar(channel,variable)
    increment_action_id
    return @client.send_action({'ActionID' => @action_id, 'Action' => 'GetVar', 'Channel' => channel, 'Variable' => variable},@timeout)
  end

  def hangup(channel=nil)
    increment_action_id
    return @client.send_action({'ActionID' => @action_id, 'Action' => 'Hangup', 'Channel' => channel},@timeout)
  end

  # IAXpeers is bugged.  The response does not contain an action id, nor does it contain any key/value pairs in the response.
  # For this reason it gets put into the state queue where it can be retrieved using find_events('any','iax2 peers').  iax_peers
  # will always return {'Response' => 'Success'}
  def iax_peers
    increment_action_id
    @client.send_action({'ActionID' => @action_id, 'Action' => 'IAXpeers'},1)
    return [{'Response' => 'Success'}]
  end

  def monitor(channel=nil,file=nil,mix=nil)
    increment_action_id
    return @client.send_action({'ActionID' => @action_id, 'Action' => 'Monitor', 'Channel' =>channel, 'File' => file, 'Mix' => mix},@timeout)
  end

  def mailbox_status(mailbox=nil)
    increment_action_id
    return @client.send_action({'ActionID' => @action_id, 'Action' => 'MailboxStatus', 'Mailbox' => mailbox},@timeout)
  end

  def queue_status
    increment_action_id
    @client.send_action({'ActionID' => @action_id, 'Action' => 'QueueStatus'}, @timeout)
  end

  def mailbox_count(mailbox=nil)
    increment_action_id
    return @client.send_action({'ActionID' => @action_id, 'Action' => 'MailboxCount', 'Mailbox' => mailbox},@timeout)
  end

  # h is a hash with the following keys.  keys that are nil will not be passed to asterisk.
  # * Channel
  # * Context
  # * Exten
  # * Priority
  # * Timeout
  # * CallerID
  # * Variable
  # * Account
  # * Application
  # * Data
  # * Async
  # If Async has a value, the method will wait until the call is hungup or fails. On hangup,
  # Asterisk will response with Hangup event, and on failure it will respond with an OriginateFailed event.
  # If Async is nil, the method will return immediately and the associated events can be obtained by calling
  # find_events() or get_events().
  def originate(h={})
    increment_action_id
    return @client.send_action({'ActionID' => @action_id,
                                'Action' => 'Originate',
                                'Channel' => h['Channel'],
                                'Context' => h['Context'],
                                'Exten' =>h['Exten'],
                                'Priority' =>h['Priority'],
                                'Timeout' =>h['Timeout'],
                                'CallerID' =>h['CallerID'],
                                'Variable' =>h['Variable'],
                                'Account' =>h['Account'],
                                'Application' =>h['Application'],
                                'Data' =>h['Data'],
                                'Async' => h['Async']}.delete_if {|key, value| value.nil? },@timeout)
  end

  def parked_calls
    increment_action_id
    return @client.send_action({'ActionID' => @action_id, 'Action' => 'ParkedCalls'},@timeout)
  end

  def ping
    increment_action_id
    return @client.send_action({'ActionID' => @action_id, 'Action' => 'Ping'},@timeout)
  end

  # Queues is just like IAXpeers.  You can use find_events('any','default') to get the response from the state queue.
  def queues
    increment_action_id
    @client.send_action({'ActionID' => @action_id, 'Action' => 'Queues'},@timeout)
    return [{'Response' => 'Success'}]
  end

  # h is a hash with the following keys.  keys that are nil will not be passed to asterisk.
  # * Channel
  # * ExtraChannel
  # * Context
  # * Exten
  # * Priority
  def redirect(h={})
    increment_action_id
    return @client.send_action({'ActionID' => @action_id,
                                'Action' => 'Redirect',
                                'Channel' => h['Channel'],
                                'ExtraChannel' => h['ExtraChannel'],
                                'Context' => h['Context'],
                                'Exten' => h['Exten'],
                                'Priority' => h['Priority']}.delete_if {|key,value| value.nil?},@timeout)
  end

  def setvar(channel,variable,value)
    increment_action_id
    return @client.send_action({'ActionID' => @action_id, 'Action' => 'SetVar', 'Channel' => channel, 'Variable' => variable, 'Value' => value},@timeout)
  end

  # Unlike IAXpeers, SIPpeers returns an event for each peer that is easily parsed and usable.
  def sip_peers
    increment_action_id
    return @client.send_action({'ActionID' => @action_id, 'Action' => 'SIPpeers'},@timeout)
  end

  # Detailed information about a particular peer.
  def sip_show_peer(peer)
    increment_action_id
    return @client.send_action({'ActionID' => @action_id, 'Action' => 'SIPshowpeer', 'Peer' => peer},@timeout)
  end

  def status(channel=nil)
    increment_action_id
    if channel.nil?
      return @client.send_action({'ActionID' => @action_id, 'Action' => 'Status'},@timeout)
    else
      return @client.send_action({'ActionID' => @action_id, 'Action' => 'Status', 'Channel' => channel},@timeout)
    end
  end

  def stop_monitor(channel=nil)
    increment_action_id
    return @client.send_action({'ActionID' => @action_id, 'Action' => 'StopMonitor', 'Channel' =>channel},@timeout)
  end

private
  def increment_action_id
    @action_id = Time.now().to_f
  end

  def send_action(action=nil,tout=nil)
    increment_action_id
    action['ActionID'] = @action_id
    return @client.send_action(action,tout)
  end

end

# To run a standalone Rami server create a Server instance and then call it's run() method.
# The server will maintain one open connection to asterisk.  It uses one thread to constantly read responses and stick them into
# the appropriate queue.
#
# The server uses two queues to hold responses from asterisk.  The action queue holds all responses that contain an ActionID.
# The state queue holds all responses that do not have an ActionID.  The action queue is only used internally, while the state
# queue can be queried via Client.get_events and Client.find_events.
#
# For an example of how to run a standalone server, see bin/server.rb.  For using the Server and Client classes together without
# starting a standalone server see the Client documentation.
class Server
  # If set to 1, console logging is turned on.  Default 0
  attr_writer :console
  # The number of responses to hold in the state queue. The state queue is a FIFO list.  Default is 100.
  attr_writer :event_cache

Thread.current.abort_on_exception=true

include DRbUndumped

# Takes a hash with the following keys:
# * host - hostname the AMI is running on
# * port - port number the AMI is running on
# * username - AMI username
# * secret - AMI secret
# * console - Set to 1 for console logging.  Default is 0 (off)
# * event_cache - Number of responses to hold in the event queue. Default 100
#
# console and event_cache are also attributes, so they can be changed after calling Server.new
def initialize(options = {})
    @console = options['console'] || 0
    @username = options['username'] || 'asterisk'
    @secret = options['secret'] || 'secret'
    @host = options['host'] || 'localhost'
    @port = options['port'] || 5038
    @event_cache = options['event_cache'] || 100

    @eventcount = 1

    @sock = nil
    @socklock = nil
    @socklock.extend(MonitorMixin)

    @action_events = []
    @action_events.extend(MonitorMixin)
    @action_events_pending = @action_events.new_cond

    @state_events = []
    @state_events.extend(MonitorMixin)
    @state_events_pending = @state_events.new_cond

end




private

def logger(type,msg)
  if @console == 1
    #print "#{Time.now} #{type} #{@eventcount}: #{msg}"
  end
end



def connect
  @sock = TCPSocket.new(@host,@port)
  login = {'Action' => 'login', 'Username' => @username, 'Secret' => @secret, 'Events' => 'On'}
  writesock(login)
  accum = {}
  login = 0
  status = Timeout.timeout(3) do
    while login == 0
      @sock.each("\r\n") do |line|
        if line.include?(':')
          key,value = parseline(line) if line.include?(':')
          accum[key] = value
        end
        logger('RECV',"#{line}")
        if line == "\r\n" and accum['Message'] == 'Authentication accepted' and accum['Response'] == 'Success'
          login =1
          @eventcount += 1
          break
        end
      end
    end
  return true
  end
rescue Timeout::Error => e
  #puts "LOGIN TIMEOUT"
  return false
end


def mainloop

  ast_reader = Thread.new do
    Thread.current.abort_on_exception=true
   begin
    linecount = 0
    loop do

      event = {}
      @sock.each("\r\n") do |line|
        linecount += 1
        type = 'state'
        logger('RECV', "#{line}")
        if line == "\r\n"
          if event.size == 0
            logger('MSG',"RECEIVED EXTRA CR/LF #{line}")
            next
          end
          if event['ActionID']
            type = 'action'
          end

          logger('MSG',"finished (type=#{type}) #{line}")

          if type == 'action'
            @action_events.synchronize do
              @action_events << event.clone
              event.clear
              @action_events_pending.signal
            end
          elsif type == 'state'
            @state_events.synchronize do
              @state_events << event.clone
              if @state_events.size >= @event_cache
                @state_events.shift
              end
              event.clear
              @state_events_pending.signal
            end
          end
          @eventcount += 1
        elsif line =~/^[\w\s\/-]*:[\s]*.*\r\n$/
          key,value = parseline(line)
          if key == 'ActionID'
            value = value.gsub(' ','')
          end
          event[key] = value
        else
          event[linecount] = line
        end
      end
    end
    rescue IOError => e
      #puts "Socket disconnected #{e}"
    end
  end
end

def parseline(line)
  if line =~/(^[\w\s\/-]*:[\s]*)(.*\r\n$)/
    key = $1
    value = $2
    key = key.gsub(/[\s:]*/,'')
    value = value.gsub(/\r\n/,'')
    return [key,value]
  else
    return ["UNKNOWN","UNKNOWN"]
  end

end


def writesock(action)
  @socklock.synchronize do
    action.each do |key,value|
      @sock.write("#{key}: #{value}\r\n")
      logger('SEND',"#{key}: #{value}\r\n")
    end
    @sock.write("\r\n")
    logger('SEND',"\r\n")
  end
end


public


# Starts the server and connects to asterisk.
def run
  if connect
    #puts "#{Time.now} MSG: LOGGED IN"
  else
    #puts "#{Time.now} MSG: LOGIN FAILED"
    exit
  end
  mainloop
end

def stop
  @sock.close
end

# Should only be called via Client
def find_events(key=nil,value=nil)
  logger('find_events',"#{key}: #{value}")
  found = []
  @state_events.synchronize do
    if @state_events.empty?
      return found
    else
      @state_events_pending.wait_while {@state_events.empty?}
      @state_events.clone.each do |e|
        if key == 'any' and e.to_s =~/#{value}/
          found.push(e)
          @state_events.delete(e)
        elsif key != 'any' and e[key] =~/#{value}/
          found.push(e)
          @state_events.delete(e)
        end
      end
      return found
    end
  end
end

# Should only be called via Client
def get_events
  found = []
  @state_events.synchronize do
    if @state_events.empty?
      return found
    else
      @state_events_pending.wait_while {@state_events.empty?}
      @state_events.clone.each do |e|
        found.push(e)
      end
      @state_events.clear
      return found
    end
  end
end

# Should only be called via Client
def send_action(action=nil,t=3)
  sent_id = action['ActionID'].to_s
  result = []
  finished = 0
  status = Timeout.timeout(t) do
    writesock(action)

    ## Some action responses have no action id or specific formatting, so we just return immediately and the caller can call
    ## get_events or find_events to get the response.

    ## IAXpeer - Just return immediately
    if action['Action'] == 'IAXpeers'
      finished =1
      return
    end

    ## Queues - Just return immediately
    if action['Action'] == 'Queues'
      finished =1
      return
    end


    while finished == 0
      @action_events.synchronize do
        @action_events_pending.wait_while {@action_events.empty?}
        @action_events.clone.each do |e|

          ## Action responses that contain an ActionID
          if e['ActionID'].to_s == sent_id

            ## Ping - Single response has ActionID
            if action['Action'] == 'Ping' and e['Response'].gsub(/\s/,'') == 'Pong'
              @action_events.delete(e)
              result << e
              finished = 1
            end

            ## Command - Single response has ActionID
            if action['Action'] == 'Command' and e['Response'].gsub(/\s/,'') == 'Follows'
              @action_events.delete(e)
              result << e
              finished = 1
            end

            ## Hangup - Single response has ActionID
            if action['Action'] == 'Hangup'
              @action_events.delete(e)
              result << e
              finished = 1
            end

            ## ExtensionState - Single response has ActionID
            if action['Action'] == 'ExtensionState'
              @action_events.delete(e)
              result << e
              finished = 1
            end

            ## SetVar - Single response has ActionID
            if action['Action'] == 'SetVar'
              @action_events.delete(e)
              result << e
              finished = 1
            end

            ## GetVar - Single response has ActionID
            if action['Action'] == 'GetVar'
              @action_events.delete(e)
              result << e
              finished = 1
            end

            ## Redirect - Single response has ActionID
            if action['Action'] == 'Redirect'
              @action_events.delete(e)
              result << e
              finished = 1
            end

            ## DBPut - Single response has ActionID
            if action['Action'] == 'DBPut'
              @action_events.delete(e)
              result << e
              finished = 1
            end

            ## DBGet - Single response has ActionID
            if action['Action'] == 'DBGet' and (e['Response'] == 'Error' or e['Event'] == 'DBGetResponse')
              @action_events.delete(e)
              result << e
              finished = 1
            end

            ## Monitor - Single response has ActionID
            if action['Action'] == 'Monitor'
              @action_events.delete(e)
              result << e
              finished = 1
            end

            ## Stop Monitor - Single response has ActionID
            if action['Action'] == 'StopMonitor'
              @action_events.delete(e)
              result << e
              finished = 1
            end

            ## ChangeMonitor - Single response has ActionID
            if action['Action'] == 'ChangeMonitor'
              @action_events.delete(e)
              result << e
              finished = 1
            end

            ## MailboxStatus - Single response has ActionID
            if action['Action'] == 'MailboxStatus'
              @action_events.delete(e)
              result << e
              finished = 1
            end

            ## MailboxCount - Single response has ActionID
            if action['Action'] == 'MailboxCount'
              @action_events.delete(e)
              result << e
              finished = 1
            end

            ## AbsoluteTimeout - Single response has ActionID
            if action['Action'] == 'AbsoluteTimeout'
              @action_events.delete(e)
              result << e
              finished = 1
            end

            ## SIPshowpeer - Single response has ActionID
            if action['Action'] == 'SIPshowpeer'
              @action_events.delete(e)
              result << e
              finished = 1
            end

            ## Logoff - Single response has ActionID
            if action['Action'] == 'Logoff'
              @action_events.delete(e)
              result << e
              finished = 1
            end


            ## Originate - Single response has ActionID, multiple events generated
            ## end event is Hangup or OriginateFailed.
            if action['Action'] == 'Originate'
              if action['Async']
                if action['Action'] == 'Originate' and e['Message'] == 'Originate successfully queued'
                  @action_events.delete(e)
                  result << e
                  finished = 1
                end
              else
                eventfinished =0
                while eventfinished == 0
                  @state_events.synchronize do
                    @state_events_pending.wait_while {@state_events.empty?}
                    @state_events.clone.each do |s|
                      if s['Channel'] =~/#{action['Channel']}/ and (s['Event'] == 'Hangup' or s['Event'] == 'OriginateFailed')
                        @state_events.delete(s)
                        result << s
                        eventfinished =1
                        finished =1
                      elsif s['Channel'] =~/#{action['Channel']}/
                        @state_events.delete(s)
                        result << s
                      end
                    end
                  end
                end
              end
            end

            ## ParkedCalls - multiple responses has ActionID
            if action['Action'] == 'ParkedCalls'
              if e['Message'] == 'Parked calls will follow'
                @action_events.delete(e)
              elsif e['Event'] == 'ParkedCallsComplete'
                @action_events.delete(e)
                finished =1
              else
                @action_events.delete(e)
                result << e
              end
            end

            ## QueueStatus - multiple responses has ActionID
            if action['Action'] == 'QueueStatus'
              if e['Message'] == 'Queue status will follow'
                @action_events.delete(e)
              elsif e['Event'] == 'QueueStatusComplete'
                @action_events.delete(e)
                finished =1
              else
                @action_events.delete(e)
                result << e
              end
            end

            ## SIPpeers - multiple responses has ActionID
            if action['Action'] == 'SIPpeers'
              if e['Message'] == 'Peer status list will follow'
                @action_events.delete(e)
              elsif e['Event'] == 'PeerlistComplete'
                @action_events.delete(e)
                finished =1
              elsif e['Event'] == 'PeerEntry'
                @action_events.delete(e)
                result << e
              end
            end

            ## Agents - multiple responses has ActionID
            if action['Action'] == 'Agents'
              if e['Message'] == 'Agents will follow'
                @action_events.delete(e)
              elsif e['Event'] == 'AgentsComplete'
                @action_events.delete(e)
                finished =1
              elsif e['Event'] == 'Agents'
                @action_events.delete(e)
                result << e
              end
            end

            ## Status - multiple responses has ActionID
            if action['Action'] == 'Status'
              if e['Message'] == 'Channel status will follow'
                @action_events.delete(e)
              elsif e['Event'] == 'StatusComplete'
                @action_events.delete(e)
                finished =1
              elsif e['Event'] == 'Status'
                @action_events.delete(e)
                result << e
              end
            end

          end
        end
      end
      sleep 0.10
    end
  end
  return result
rescue Exception => e
  #puts "#{e}: TIMEOUT #{t} #{sent_id}"
  return result
end

end
  rescue Exception => e
  #puts e
end