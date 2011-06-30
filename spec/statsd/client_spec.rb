require "helper"

describe Statsd::Client do
  before do
    @client = Statsd::Client.new("localhost", 1234)
    class << @client
      attr_reader :host, :port # we also need to test this
      def socket; @socket ||= FakeUDPSocket.new end
    end
  end

  after { @client.socket.clear }

  describe "#initialize" do
    it "should set the host and port" do
      @client.host.should == "localhost"
      @client.port.should == 1234
    end

    it "should default the port to 8125" do
      Statsd::Client.new("localhost").instance_variable_get("@port").should == 8125
    end
  end

  describe "#increment" do
    it "should format the message according to the statsd spec" do
      @client.increment("foobar")
      @client.socket.recv.should == [Statsd::Message.new.add_metric(:m, "foobar", 1).to_s]
    end
  end

  describe "#timing" do
    it "should format the message according to the statsd spec" do
      @client.timing("foobar", 500)
      @client.socket.recv.should == [Statsd::Message.new.add_metric(:h, "foobar", 500).to_s]
    end
  end

  describe "#time" do
    it "should format the message according to the statsd spec" do
      @client.time("foobar") { sleep(0.001); "test" }
      @client.socket.recv.should == [Statsd::Message.new.add_metric(:h, "foobar", 1).to_s]
    end

    it "should return the result of the block" do
      result = @client.time("foobar") { sleep(0.001); "test" }
      result.should == "test"
    end
  end

  describe "with namespace" do
    before { @client.namespace = "service" }

    it "should add namespace to increment" do
      @client.increment("foobar")
      @client.socket.recv.should == [Statsd::Message.new.add_metric(:m, "service.foobar", 1).to_s]
    end

    it "should add namespace to timing" do
      @client.timing("foobar", 500)
      @client.socket.recv.should == [Statsd::Message.new.add_metric(:h, "service.foobar", 500).to_s]
    end
  end
end

describe Statsd do
  describe "with a real UDP socket" do
    it "should actually send stuff over the socket" do
      socket = UDPSocket.new
      host, port = "localhost", 12345
      socket.bind(host, port)

      statsd = Statsd::Client.new(host, port)
      statsd.increment("foobar")
      message = socket.recvfrom(16).first
      message.should == Statsd::Message.new.add_metric(:m, "foobar", 1).to_s
    end
  end
end
