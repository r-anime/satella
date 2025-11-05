require 'active_support/inflector'
require 'bunny'

class RabbitService
  RABBIT_QUEUE_ENV_PREFIX = 'RABBITMQ_QUEUE_'
  ATTEMPT_HEADER = ENV['RABBITMQ_RETRY_ATTEMPT_HEADER']
  MAX_ATTEMPTS = ENV['RABBITMQ_MAX_ATTEMPTS'].to_i

  def initialize(
    host: 'http://localhost',
    port: 5672,
    username: 'guest',
    password: 'guest',
    vhost: '/',
    retry_exchange_name: 'retry',
    queues: [],
    log_level: 'warn',
    handlers: {}
  )
    @retry_exchange_name = retry_exchange_name
    @queues = queues
    @handlers = handlers

    puts "#{{host:, port:, username:, password:, vhost:, log_level:}}"
    @connection = Bunny.new(host:, port:, username:, password:, vhost:, log_level:)
  end

  def listen!()
    @connection.start
    channel = @connection.create_channel
    retry_exchange = channel.direct(@retry_exchange_name, durable: true)
    $logger.info "Connected to #{@retry_exchange_name}"

    @queues.each do |queue_key, value|
      queue_name = value[:queue_name]
      handler = value[:handler]
      next if queue_key == 'mod_actions' # DEBUG
      setup_listener(channel, queue_name, retry_exchange, handler)
    end

    $logger.info "✅ Listening on #{@queues.values.join(', ')}"
    sleep
  rescue Interrupt
    $logger.info "\nShutting down..."
    @connection.close if @connection.open?
  end

  private

  def setup_listener(channel, queue_name, retry_exchange, handler)
    queue = channel.queue(queue_name, durable: true)

    queue.subscribe(block: false, manual_ack: true) do |delivery_info, properties, body|
      handler.call(JSON.parse(body, symbolize_names: true))

      delivery_info.channel.ack(delivery_info.delivery_tag)
      exit # DEBUG
    rescue => e
      attempt = properties&.headers&.[](ATTEMPT_HEADER) || 1
      if attempt < MAX_ATTEMPTS
        $logger.warn "[#{queue_name}] Handler error (#{attempt}/#{MAX_ATTEMPTS} retrying): #{e.class}: #{e.message}"
        $logger.warn e.backtrace.join("\n")
        retry_exchange.publish(
          body,
          headers: {ATTEMPT_HEADER => attempt + 1},
          persistent: true,
          routing_key: delivery_info.routing_key,
          content_type: properties.content_type
        )
        delivery_info.channel.ack(delivery_info.delivery_tag)
      else
        $logger.warn "[#{queue_name}] Handler error (#{attempt}/#{MAX_ATTEMPTS} dead lettering): #{e.class}: #{e.message}"
        $logger.warn e.backtrace.join("\n")
        delivery_info.channel.nack(delivery_info.delivery_tag, false, false)
      end
      exit # DEBUG
    end
  end
end
