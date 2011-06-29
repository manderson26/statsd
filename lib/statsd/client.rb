require 'socket'

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
      @host, @port = host, port
    end

    # @param [String] stat stat name
    # @param [Integer] sample_rate sample rate, 1 for always
    def increment(key, sample_rate=nil)
      count(key, 1, sample_rate)
    end

    # @param [String] stat stat name
    # @param [Integer] sample_rate sample rate, 1 for always
    def decrement(key, sample_rate=nil)
      count(key, -1, sample_rate)
    end

    # @param [String] stat stat name
    # @param [Integer] count count
    # @param [Integer] sample_rate sample rate, 1 for always
    def count(key, count, sample_rate=nil)
      send_stats("c", key, count, sample_rate)
    end

    # @param [String] stat stat name
    # @param [Integer] ms timing in milliseconds
    # @param [Integer] sample_rate sample rate, 1 for always
    def timing(key, ms, sample_rate=nil)
      send_stats('ms', key, ms, sample_rate)
    end

    # @param [String] stat stat name
    # @param [Integer] ms timing in milliseconds
    # @param [Integer] sample_rate sample rate, 1 for always
    def meter_reader(key, v, sample_rate=nil)
      send_stats('mr', key, v, sample_rate)
    end


    def time(key, sample_rate=nil)
      start = Time.now
      result = yield
      timing(key, ((Time.now - start) * 1000).round, sample_rate)
      result
    end

    private

    def sampled(sample_rate)
      yield unless sample_rate < 1 and rand > sample_rate
    end

    def send_stats(type, key, value, sample_rate=nil)
      sample_rate = 1 if sample_rate.nil? # shim the old interface for now.
      prefix = "#{@namespace}." unless @namespace.nil?
      sampled(sample_rate) { socket.send("#{prefix}#{key}:#{value}|#{type}#{'|@' << sample_rate.to_s if sample_rate < 1}", 0, @host, @port) }
    end

    def socket
      @socket ||= UDPSocket.new
    end

  end
end

