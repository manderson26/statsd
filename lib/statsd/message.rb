module Statsd
  class Message

    class InvalidMessageType < ArgumentError
    end

    PROTOCOL_VERSION = "1".freeze
    PRIMITIVES = {:meter        => "m",
                  :m            => "m",
                  :meter_reader => "mr",
                  :mr           => "mr",
                  :gauge        => "g",
                  :g            => "g",
                  :histogram    => "h",
                  :h            => "h" }

    attr_reader :body

    def initialize
      @body = ""
    end

    def content_length
      @body.bytesize
    end

    def add_metric(type, key, value, sample_rate=nil)

      unless type_str = PRIMITIVES[type]
        raise InvalidMessageType, "message type #{type.inspect} is invalid"
      end

      if sample_rate.nil?
        @body << "#{key}:#{value}|#{type_str}\n"
      elsif writing_sample?(sample_rate)
        @body << "#{key}:#{value}|#{type_str}|@#{sample_rate}\n"
      end

      self
    end

    def to_s
      "#{PROTOCOL_VERSION}|#{content_length}\n#{@body}"
    end

    def writing_sample?(sample_rate)
      ( sample_rate >= 1 ) || ( Kernel.rand <= sample_rate )
    end

  end
end

