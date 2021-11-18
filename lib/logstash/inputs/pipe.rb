# encoding: utf-8
require "logstash/environment"
if LogStash::Environment.windows?
  raise Exception("This plugin does not work on Microsoft Windows.")
end
require "logstash/inputs/base"
require "logstash/namespace"
require "socket" # for Socket.gethostname
require "stud/interval"

require 'logstash/plugin_mixins/ecs_compatibility_support'

# Stream events from a long running command pipe.
#
# By default, each event is assumed to be one line. If you
# want to join lines, you'll want to use the multiline codec.
#
class LogStash::Inputs::Pipe < LogStash::Inputs::Base

  include LogStash::PluginMixins::ECSCompatibilitySupport(:disabled, :v1, :v8 => :v1)

  config_name "pipe"

  # TODO(sissel): This should switch to use the `line` codec by default
  # once we switch away from doing 'readline'
  default :codec, "plain"

  # Command to run and read events from, one line at a time.
  #
  # Example:
  # [source,ruby]
  #    command => "echo hello world"
  config :command, :validate => :string, :required => true

  def initialize(params)
    super
    @pipe = nil
  end # def initialize

  public
  def register
    @logger.debug("Registering pipe input", :command => @command)

    @hostname = Socket.gethostname.freeze

    @host_name_field =            ecs_select[disabled: 'host',    v1: '[host][name]']
    @process_command_line_field = ecs_select[disabled: 'command', v1: '[process][command_line]']
  end # def register

  public
  def run(queue)
    while !stop?
      begin
        pipe = @pipe = IO.popen(@command, "r")

        pipe.each do |line|
          line = line.chomp
          @logger.debug? && @logger.debug("Received line", :command => @command, :line => line)

          @codec.decode(line) do |event|
            decorate(event)
            event.set(@host_name_field, @hostname) unless event.include?(@host_name_field)
            event.set(@process_command_line_field, @command) unless event.include?(@process_command_line_field)
            queue << event
          end
        end
        pipe.close
        @pipe = nil
      rescue Exception => e
        @logger.error("Exception while running command", :exception => e, :backtrace => e.backtrace)
      end

      # Keep running the command forever.
      Stud.stoppable_sleep(10) do
        stop?
      end
    end
  end # def run

  def stop
    pipe = @pipe
    if pipe
      Process.kill("KILL", pipe.pid) rescue nil
      pipe.close rescue nil
      @pipe = nil
    end
  end
end # class LogStash::Inputs::Pipe
