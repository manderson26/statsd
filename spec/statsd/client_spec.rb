require 'helper'

describe Statsd::Client do
  before do
    @client = Statsd::Client.new('localhost', 1234)
    class << @client
      public :sampled # we need to test this
      attr_reader :host, :port # we also need to test this
      def socket; @socket ||= FakeUDPSocket.new end
    end
  end

  after { @client.socket.clear }

  describe "#initialize" do
    it "should set the host and port" do
      @client.host.should == 'localhost'
      @client.port.should == 1234
    end

    it "should default the port to 8125" do
      Statsd::Client.new('localhost').instance_variable_get('@port').should == 8125
    end
  end

  describe "#increment" do
    it "should format the message according to the statsd spec" do
      @client.increment('foobar')
      @client.socket.recv.should == ['foobar:1|c']
    end

    describe "with a sample rate" do
      before { class << @client; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @client.increment('foobar', 0.5)
        @client.socket.recv.should == ['foobar:1|c|@0.5']
      end
    end
  end

  describe "#decrement" do
    it "should format the message according to the statsd spec" do
      @client.decrement('foobar')
      @client.socket.recv.should == ['foobar:-1|c']
    end

    describe "with a sample rate" do
      before { class << @client; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @client.decrement('foobar', 0.5)
        @client.socket.recv.should == ['foobar:-1|c|@0.5']
      end
    end
  end

  describe "#timing" do
    it "should format the message according to the statsd spec" do
      @client.timing('foobar', 500)
      @client.socket.recv.should == ['foobar:500|ms']
    end

    describe "with a sample rate" do
      before { class << @client; def rand; 0; end; end } # ensure delivery
      it "should format the message according to the statsd spec" do
        @client.timing('foobar', 500, 0.5)
        @client.socket.recv.should == ['foobar:500|ms|@0.5']
      end
    end
  end

  describe "#time" do
    it "should format the message according to the statsd spec" do
      @client.time('foobar') { sleep(0.001); 'test' }
      @client.socket.recv.should == ['foobar:1|ms']
    end

    it "should return the result of the block" do
      result = @client.time('foobar') { sleep(0.001); 'test' }
      result.should == 'test'
    end

    describe "with a sample rate" do
      before { class << @client; def rand; 0; end; end } # ensure delivery

      it "should format the message according to the statsd spec" do
        result = @client.time('foobar', 0.5) { sleep(0.001); 'test' }
        @client.socket.recv.should == ['foobar:1|ms|@0.5']
      end
    end
  end

  describe "#sampled" do
    describe "when the sample rate is 1" do
      it "should yield" do
        @client.sampled(1) { :yielded }.should == :yielded
      end
    end

    describe "when the sample rate is greater than a random value [0,1]" do
      before { class << @client; def rand; 0; end; end } # ensure delivery
      it "should yield" do
        @client.sampled(0.5) { :yielded }.should == :yielded
      end
    end

    describe "when the sample rate is less than a random value [0,1]" do
      before { class << @client; def rand; 1; end; end } # ensure no delivery
      it "should not yield" do
        @client.sampled(0.5) { :yielded }.should == nil
      end
    end

    describe "when the sample rate is equal to a random value [0,1]" do
      before { class << @client; def rand; 0.5; end; end } # ensure delivery
      it "should yield" do
        @client.sampled(0.5) { :yielded }.should == :yielded
      end
    end
  end

  describe "with namespace" do
    before { @client.namespace = 'service' }

    it "should add namespace to increment" do
      @client.increment('foobar')
      @client.socket.recv.should == ['service.foobar:1|c']
    end

    it "should add namespace to decrement" do
      @client.decrement('foobar')
      @client.socket.recv.should == ['service.foobar:-1|c']
    end

    it "should add namespace to timing" do
      @client.timing('foobar', 500)
      @client.socket.recv.should == ['service.foobar:500|ms']
    end
  end
end

describe Statsd do
  describe "with a real UDP socket" do
    it "should actually send stuff over the socket" do
      socket = UDPSocket.new
      host, port = 'localhost', 12345
      socket.bind(host, port)

      statsd = Statsd::Client.new(host, port)
      statsd.increment('foobar')
      message = socket.recvfrom(16).first
      message.should == 'foobar:1|c'
    end
  end
end
