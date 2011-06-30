require 'socket'

require 'statsd/message'

module Statsd
  # = Statsd: A Statsd client (https://github.com/etsy/statsd)
  #
  # Example:
  #
  #     statsd = Statsd.new 'localhost', 8125
  #
  #     statsd.increment 'garets'
  #     statsd.timing 'glork', 320
  class Client
    attr_accessor :namespace

    # @param [String] host your statsd host
    # @param [Integer] port your statsd port
    def initialize(host, port=8125)
      @namespace = nil
      @host, @port = host, port
    end

    # @param [String] key (relative) metric key
    # @param [Integer] sample_rate sample rate, 1 for always
    def mark(key, sample_rate=nil)
      send_stats(:meter, key, 1, sample_rate)
    end

    alias :increment :mark

    # @param [String] key (relative) metric key
    # @param [Integer] count count
    # @param [Integer] sample_rate sample rate, 1 for always
    def histogram(key, count, sample_rate=nil)
      send_stats(:histogram, key, count, sample_rate)
    end

    alias :count :histogram

    # @param [String] key (relative) metric key
    # @param [Integer] ms timing in milliseconds
    # @param [Integer] sample_rate sample rate, 1 for always
    def timing(key, ms, sample_rate=nil)
      send_stats(:histogram, key, ms, sample_rate)
    end

    # @param [String] stat stat name
    # @param [Integer] ms timing in milliseconds
    # @param [Integer] sample_rate sample rate, 1 for always
    def meter_reader(key, v, sample_rate=nil)
      send_stats(:meter_reader, key, v, sample_rate)
    end


    def time(key, sample_rate=nil)
      start = Time.now
      result = yield
      timing(key, ((Time.now - start) * 1000).round, sample_rate)
      result
    end

    private

    def send_stats(type, key, value, sample_rate=nil)
      prefix = "#{@namespace}." unless @namespace.nil?
      #"#{prefix}#{key}:#{value}|#{type}#{'|@' << sample_rate.to_s if sample_rate < 1}"
      message = Message.new.add_metric(type, "#{prefix}#{key}", value, sample_rate)
      socket.send(message.to_s, 0, @host, @port) unless message.content_length == 0
    end

    def socket
      @socket ||= UDPSocket.new
    end

  end
end

