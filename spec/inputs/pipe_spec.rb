# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
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

  describe "pipe from echo" do

    let(:config) do <<-CONFIG
      input {
        pipe {
          command => "echo ☹"
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
      expect(event["message"]).to eq("☹")
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
      event_count.times do |i|
        expect(events[i]["message"]).to eq("#{i} ☹")
      end
    end
  end
end
