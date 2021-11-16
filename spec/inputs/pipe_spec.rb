# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/devutils/rspec/shared_examples"
require 'logstash/plugin_mixins/ecs_compatibility_support/spec_helper'
require "logstash/inputs/pipe"
require "tempfile"

describe LogStash::Inputs::Pipe, :unix => true do

  it "should register" do
    input = LogStash::Plugin.lookup("input", "pipe").new("command" => "echo 'world'")

    # register will try to load jars and raise if it cannot find jars or if org.apache.log4j.spi.LoggingEvent class is not present
    expect {input.register}.to_not raise_error
  end

  context "when interrupting the plugin" do

    it_behaves_like "an interruptible input plugin" do
      let(:config) { { "command" => "echo ☹" } }
    end

    it_behaves_like "an interruptible input plugin" do
      let(:config) { { "command" => "echo foo" } }
    end

  end

  describe "pipe from echo", :ecs_compatibility_support do

    ecs_compatibility_matrix(:disabled, :v1, :v8) do |ecs_select|

      let(:config) do <<-CONFIG
        input {
          pipe {
            command => "echo ☹"
            ecs_compatibility => "#{ecs_compatibility}"
          }
        }
      CONFIG
      end

      let(:event) do
        input(config) do |pipeline, queue|
          queue.pop
        end
      end

      it "should receive the pipe" do
        expect(event.get("message")).to eq("☹")
      end

      it "sets host field" do
        if ecs_select.active_mode == :disabled
          expect(event.get("host")).to be_a String
        else
          expect(event.get("[host][name]")).to be_a String
        end
      end

      it "sets the command executed" do
        if ecs_select.active_mode == :disabled
          expect(event.get("command")).to eql "echo ☹"
        else
          expect(event.include?("command")).to be false
          expect(event.get("[process][command_line]")).to eql "echo ☹"
        end
      end

    end

  end

  describe "pipe from tail" do

    let(:tmp_file)    { Tempfile.new('logstash-spec-input-pipe') }
    let(:event_count) { 10 }

    let(:config) do <<-CONFIG
    input {
        pipe {
          command => "tail -n +0 -f #{tmp_file.path}"
        }
      }
    CONFIG
    end

    let(:events) do
      input(config) do |pipeline, queue|
        File.open(tmp_file, "a") do |fd|
          event_count.times do |i|
            # unicode smiley for testing unicode support!
            fd.puts("#{i} ☹")
          end
        end
        event_count.times.map { queue.pop }
      end
    end

    it "should receive all piped elements" do
      messages = event_count.times.map { |i| events[i].get("message") }
      expect( messages.sort ).to eql event_count.times.map { |i| "#{i} ☹" }
    end
  end
end
