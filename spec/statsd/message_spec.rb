require File.expand_path('../../helper', __FILE__)

describe Statsd::Message do
  before do
    @message = Statsd::Message.new
  end

  it "has a content length" do
    @message.content_length.should == 0
  end

  it "has a protocol_version" do
    Statsd::Message::PROTOCOL_VERSION.should == "1"
  end

  it "has an empty body" do
    @message.body.should == ""
  end

  it "converts to a string in the protocol format" do
    @message.to_s.should == "1|0\n"
  end

  it "is angry when you try to add an unsupported metric type" do
    sadtimes = lambda { @message.add_metric(:unsupported_type, "wtf", 1) }
    sadtimes.should raise_error(Statsd::Message::InvalidMessageType)
  end

  describe "when a meter metric has been added" do
    before do
      @message.add_metric :meter, "myWebservice.requests", 1
    end

    it "contains the metric in the body" do
      @message.body.should == "myWebservice.requests:1|m\n"
    end

    it "reports the content length as the size in bytes of the message body" do
      @message.content_length.should == "myWebservice.requests:1|m\n".bytesize
    end

    it "converts to a string containing the protocol header and the message" do
      content_length = "myWebservice.requests:1|m\n".bytesize
      @message.to_s.should == "1|#{content_length}\nmyWebservice.requests:1|m\n"
    end

    describe "and another metric is added" do
      before do
        @message.add_metric(:histogram, "myWebservice.requestTime", 85)
        @expected_body = "myWebservice.requests:1|m\nmyWebservice.requestTime:85|h\n"
      end

      it "contains both metrics in the message body" do
        @message.body.should == @expected_body
      end

      it "gives the content length as the size of the body with both messages" do
        @message.content_length.should == @expected_body.bytesize
      end

      it "converts to a string with the protocol header and message" do
        content_length = @expected_body.bytesize
        @message.to_s.should == "1|#{content_length}\n#{@expected_body}"
      end
    end

  end

  describe "when sending a sampled metric" do
    it "writes the metric when the sample rate execeeds a random decimal number" do
      Kernel.stub!(:rand).and_return(0.01)
      @message.should be_writing_sample(0.1)
      Kernel.stub!(:rand).and_return(0.2)
      @message.should_not be_writing_sample(0.1)
    end

    describe "and the metric was not selected as a sample" do
      before do
        Kernel.stub!(:rand).and_return(0.5)
        @message.add_metric(:histogram, "database.yuslow", 200, 0.1)
      end

      it "does not have the metric in the message body" do
        @message.body.should == ''
      end
    end

    describe "and the metric was selected as a sample" do
      before do
        Kernel.stub!(:rand).and_return(0.05)
        @message.add_metric(:histogram, "database.yuslow", 200, 0.1)
      end

      it "has the metric in the message body including sampling rate" do
        @message.body.should == "database.yuslow:200|h|@0.1\n"
      end
    end
  end


end

