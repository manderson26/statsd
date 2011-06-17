module Statsd
  #==Statsd::Middleware
  # Rack middleware for collecting metrics via statsd.
  #
  #===Basic Use
  # config.ru:
  #   use Statsd::Middleware, :namespace => ['apiService.application', 'apiService.apiServer-123abcf'],
  #                           :host => 'statsd-host.example.com',
  #                           :port => 3344
  #
  #===Default Metrics
  # By default, this middleware records response time and increments a requests
  # counter in the namespace(s) you specify in the initializer options.
  #
  #===Dynamic Keys
  # Since this middleware has no way to know what controllers or actions will
  # be called for a given request, an API is provided for you to add additional
  # keys in your application. For each request, an empty Array will be provided
  # in the rack environment hash for <tt>statsd.increments</tt> and
  # <tt>statsd.timers</tt>. So to measure the number of hits to the index
  # action of your posts controller, you can do something like this (rails):
  #   request.env['statsd.increments'] << "posts.index"
  # ...and to measure the request time:
  #   request.env['statsd.timers'] << "posts.index"
  #===Custom Metrics
  # The statsd client can be accessed via the rack env hash with the
  # <tt>statsd.client</tt> key. For example, you can count the number of calls
  # to an upstream service like this:
  #   request.env['statsd.client'].increment("s3Calls")
  #   AWS::S3.talk_to_aws
  class Middleware
    STATSD_DOT_CLIENT     = 'statsd.client'.freeze
    STATSD_DOT_INCREMENTS = 'statsd.increments'.freeze
    STATSD_DOT_TIMERS     = 'statsd.timers'.freeze

    def initialize(app, options={})
      options = options.dup

      @app              = app
      @host             = options[:host] || 'localhost'
      @port             = options[:port] || 3344
      @namespace        = Array(options[:namespace] || "rackMiddleware")

      @client = Statsd::Client.new(@host, @port)
    end

    def call(env)
      # Pass statsd client in to the request
      env[STATSD_DOT_CLIENT]      = @client
      # Set the initial list of keys to increment, pass it in to the request
      env[STATSD_DOT_INCREMENTS]  = ['allRequests']
      # Set the initial list of keys to record request time for, pass it in to the request
      env[STATSD_DOT_TIMERS]      = ['allRequests']

      # Run request
      (status, headers, body), response_time = timer{ @app.call(env) }

      # Count the requests by status code
      env[STATSD_DOT_INCREMENTS] << "byStatusCode.#{status}"

      # Actually do the statd-ing
      Array(env[STATSD_DOT_INCREMENTS]).each do |sub_namespace|
        each_namespace_with(sub_namespace) {|ns| @client.increment(ns)}
      end
      Array(env[STATSD_DOT_TIMERS]).each do |sub_namespace|
        each_namespace_with(sub_namespace) {|ns| @client.timing(ns, response_time)}
      end

      # Rack response
      [status, headers, body]
    rescue Exception
      each_namespace_with('uncaughtExceptions') {|ns| @client.increment(ns)}
      raise
    end

    def timer
      start = Time.now
      result = yield
      [result, ((Time.now - start) * 1000).round]
    end

    def each_namespace_with(sub_namespace)
      @namepace.each {|n| yield "#{n}.#{sub_namespace}"}
    end

  end
end

