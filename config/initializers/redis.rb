# Redis configuration
$redis = Redis.new(
  host: ENV.fetch("REDIS_HOST", "localhost"),
  port: ENV.fetch("REDIS_PORT", 6379).to_i,
  db: ENV.fetch("REDIS_DB", 0).to_i
)

# Test Redis connection
begin
  $redis.ping
  Rails.logger.info "Redis connected successfully"
rescue Redis::CannotConnectError => e
  Rails.logger.error "Redis connection failed: #{e.message}"
end
