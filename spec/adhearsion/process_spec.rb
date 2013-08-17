# encoding: utf-8

require 'spec_helper'

module Adhearsion
  describe Adhearsion::Process do
    before :all do
      Adhearsion.active_calls.clear
    end

    before :each do
      Adhearsion.process.reset
    end

    it 'should trigger :stop_requested events on #shutdown' do
      Events.should_receive(:trigger_immediately).once.with(:stop_requested).ordered
      Events.should_receive(:trigger_immediately).once.with(:shutdown).ordered
      Adhearsion.process.booted
      Adhearsion.process.shutdown
      sleep 0.2
    end

    it '#stop_when_zero_calls should wait until the list of active calls reaches 0' do
      pending
      calls = []
      3.times do
        fake_call = Object.new
        fake_call.should_receive(:hangup).once
        calls << fake_call
      end
      Adhearsion.should_receive(:active_calls).and_return calls
      subject.should_receive(:final_shutdown).once
      blocking_threads = []
      3.times do
        blocking_threads << Thread.new do
          sleep 1
          calls.pop
        end
      end
      subject.stop_when_zero_calls
      blocking_threads.each { |thread| thread.join }
    end

    it 'should terminate the process immediately on #force_stop' do
      ::Process.should_receive(:exit).with(1).once.and_return true
      subject.force_stop
    end

    describe "#final_shutdown" do
      it "should hang up active calls" do
        3.times do
          fake_call = Call.new
          fake_call.stub :id => random_call_id
          fake_call.should_receive(:hangup).once
          Adhearsion.active_calls << fake_call
        end

        subject.final_shutdown

        Adhearsion.active_calls.clear
      end

      it "should trigger shutdown handlers synchronously" do
        foo = lambda { |b| b }

        foo.should_receive(:[]).once.with(:a).ordered
        foo.should_receive(:[]).once.with(:b).ordered
        foo.should_receive(:[]).once.with(:c).ordered

        Events.shutdown { sleep 2; foo[:a] }
        Events.shutdown { sleep 1; foo[:b] }
        Events.shutdown { foo[:c] }

        subject.final_shutdown
      end

      it "should stop the console" do
        Console.should_receive(:stop).once
        subject.final_shutdown
      end
    end

    it 'should handle subsequent :shutdown events in the correct order' do
      subject.booted
      subject.state_name.should be :running
      subject.shutdown
      subject.state_name.should be :stopping
      subject.shutdown
      subject.state_name.should be :rejecting
      subject.shutdown
      subject.state_name.should be :stopped
      ::Process.should_receive(:exit).once.with(1)
      subject.shutdown
      sleep 0.2
    end
  end
end
