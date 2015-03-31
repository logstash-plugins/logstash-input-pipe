# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "tempfile"

describe "inputs/pipe", :unix => true do

  # rince and repeat a few times to stress the shutdown sequence
  5.times.each do
    it "should pipe from echo" do
      conf = <<-CONFIG
      input {
        pipe {
          command => "echo ☹"
        }
      }
      CONFIG

      event = input(conf) do |pipeline, queue|
        queue.pop
      end

      insist { event["message"] } == "☹"
    end
  end

  # rince and repeat a few times to stress the shutdown sequence
  5.times.each do
    it "should pipe from tail -f" do
      event_count = 10
      tmp_file = Tempfile.new('logstash-spec-input-pipe')

      conf = <<-CONFIG
      input {
        pipe {
          command => "tail -n +0 -f #{tmp_file.path}"
        }
      }
      CONFIG

      events = input(conf) do |pipeline, queue|
        File.open(tmp_file, "a") do |fd|
          event_count.times do |i|
            # unicode smiley for testing unicode support!
            fd.puts("#{i} ☹")
          end
        end
        event_count.times.map { queue.pop }
      end

      event_count.times do |i|
        insist { events[i]["message"] } == "#{i} ☹"
      end
    end
  end
end
