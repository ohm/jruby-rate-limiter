class RateLimiter
  RESOLUTION = 1_000.freeze # milliseconds

  attr_reader :rate

  def initialize(rate)
    @rate   = rate
    @limit  = @rate * RESOLUTION
    @tokens = java.util.concurrent.atomic.AtomicInteger.new(@limit)
    @time   = java.util.concurrent.atomic.AtomicLong.new(java.lang.System.current_time_millis)
  end

  def limited?
    credit = 0
    return false if @tokens.add_and_get(-RESOLUTION) > 0
    credit = RESOLUTION
    true
  ensure
    now = java.lang.System.current_time_millis
    elapsed = now - @time.get_and_set(now)
    if @tokens.add_and_get(@rate * elapsed + credit) > @limit
      @tokens.set(@limit)
    end
  end
end


