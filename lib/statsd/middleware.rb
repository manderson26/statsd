require 'statsd/client'
module Statsd
  #==Statsd::Middleware
  # Rack middleware for collecting metrics via statsd.
  #
  #===Basic Use
  # config.ru:
  #   use Statsd::Middleware, :service_key  => 'apiService.application',
  #                           :host_key     => 'apiService.apiServer-123abcf',
  #                           :host         => 'statsd-host.example.com',
  #                           :port         => 3344
  #====Config Options
  # service_key::: statsd/graphite namespace to use for service-specific metrics
  # host_key::: statsd/graphite namespace to use for host-specific metrics
  # host::: hostname/IP of the statsd server
  # port::: port that the statsd server listens on
  #
  # service_key vs. host_key: Presumably, you will want to record some
  # business-y metrics, such as user logins, only on a service-wide basis,
  # while other metrics, such as performance measurements, you will want to
  # keep both in aggregate and on a per-host basis (to diagnose problem hosts,
  # watch in-progress deployments of new code, etc.). This middleware exposes a
  # statsd client for both use cases, so you need to configure both namespaces.
  #
  #===Default Metrics
  # By default, this middleware records response time and increments a requests
  # counter in host and service namespaces you specify in the initializer options.
  #
  #===Recording Timing and Request Counters to Custom Keys
  # You will probably want to record request timing and counter metrics at a
  # higher level of detail than all requests. For example, you probably want to
  # know the rate of requests and response times for individual controller
  # actions, but this information is not available at the middleware level.
  #
  # To accomplish this an API is provided for you to add additional metrics
  # keys in your application. For each request, an Array will be provided in
  # the rack environment hash for <tt>statsd.host.increments</tt>,
  # <tt>statsd.service.increments</tt>, <tt>statsd.host.timers</tt> and
  # <tt>statsd.service.timers</tt>. So to measure the number of hits to the
  # index action of your posts controller, you can do something like this
  # (rails):
  #   # Will increment the number of hits to PostsController#index on this host:
  #   request.env['statsd.host.increments'] << "controllerActions.posts.index"
  #   # Will increment the number of hits to PostsController#index service-wide:
  #   request.env['statsd.service.increments'] << 'controllerActions.posts.index'
  # ...and to measure the request time:
  #   # Will log the request time for PostsController#index for this host:
  #   request.env['statsd.host.timers'] << "posts.index"
  #   request.env['statsd.service.timers'] << "posts.index"
  # Note that statsd keeps counters and timers in separate top level namespaces
  # on it's own, so you can re-use the same keys.
  #===Custom Metrics
  # The statsd client can be accessed via the rack env hash with the
  # <tt>statsd.client</tt> key. For example, you can count the number of calls
  # to an upstream service like this:
  #   request.env['statsd.client'].increment("s3Calls")
  #   AWS::S3.talk_to_aws
  # The statsd clients for the host and service namespaces are also available:
  #   request.env['statsd.service.client'].increment('databaseRequests')
  #   YourDatabase.make_a_request
  #
  #   request.env['statsd.host.client'].time('upstreamService') { make_upstream_request }
  #
  class Middleware
    STATSD_DOT_CLIENT = 'statsd.client'.freeze

    STATSD_DOT_HOST_DOT_CLIENT     = 'statsd.host.client'.freeze
    STATSD_DOT_HOST_DOT_INCREMENTS = 'statsd.host.increments'.freeze
    STATSD_DOT_HOST_DOT_TIMERS     = 'statsd.host.timers'.freeze

    STATSD_DOT_SERVICE_DOT_CLIENT     = 'statsd.service.client'.freeze
    STATSD_DOT_SERVICE_DOT_INCREMENTS = 'statsd.service.increments'.freeze
    STATSD_DOT_SERVICE_DOT_TIMERS     = 'statsd.service.timers'.freeze

    def initialize(app, options={})
      options = options.dup

      @app              = app
      @host             = options[:host] || 'localhost'
      @port             = options[:port] || 3344

      @service_namespace = options[:service_key] or
        raise ArgumentError, "You need to specify the namespace for service metrics (:service_key => 'myservice.global')"
      @host_namespace = options[:host_key] or
        raise ArgumentError, "You need to specify the namespace for host metrics (:host_key => 'myservice.HOSTNAME')"

      @client = Statsd::Client.new(@host, @port)
      @service_client = Statsd::Client.new(@host, @port)
      @service_client.namespace = @service_namespace
      @host_client = Statsd::Client.new(@host, @port)
      @host_client.namespace = @host_namespace
    end

    def call(env)
      # Pass statsd client in to the request
      env[STATSD_DOT_CLIENT]             = @client
      env[STATSD_DOT_HOST_DOT_CLIENT]    = @host_client
      env[STATSD_DOT_SERVICE_DOT_CLIENT] = @service_client

      # Set the initial list of keys to increment, pass it in to the request
      env[STATSD_DOT_HOST_DOT_INCREMENTS]    = ['allRequests']
      env[STATSD_DOT_SERVICE_DOT_INCREMENTS] = ['allRequests']

      # Set the initial list of keys to record request time for, pass it in to the request
      env[STATSD_DOT_HOST_DOT_TIMERS]    = ['allRequests']
      env[STATSD_DOT_SERVICE_DOT_TIMERS] = ['allRequests']

      # Run request
      (status, headers, body), response_time = call_with_timing(env)

      # Count the requests by status code
      key = "byStatusCode.#{status}"
      env[STATSD_DOT_HOST_DOT_INCREMENTS]    << key
      env[STATSD_DOT_SERVICE_DOT_INCREMENTS] << key

      # Actually do the statd-ing
      Array(env[STATSD_DOT_HOST_DOT_INCREMENTS]).each { |k| @host_client.increment(k) }
      Array(env[STATSD_DOT_SERVICE_DOT_INCREMENTS]).each {|k| @service_client.increment(k)}
      Array(env[STATSD_DOT_HOST_DOT_TIMERS]).each {|k| @host_client.timing(k, response_time)}
      Array(env[STATSD_DOT_SERVICE_DOT_TIMERS]).each {|k| @service_client.timing(k, response_time)}

      # Rack response
      [status, headers, body]
    rescue Exception => e
      # pp e, e.backtrace
      @host_client.increment("uncaughtExceptions")
      @service_client.increment("uncaughtExceptions")
      raise
    end

    def call_with_timing(env)
      start = Time.now
      result = @app.call(env)
      [result, ((Time.now - start) * 1000).round]
    end

  end
end

