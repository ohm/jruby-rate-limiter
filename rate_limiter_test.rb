# encoding: utf-8

require 'minitest/autorun'
require 'thread'

Thread.abort_on_exception = true

require_relative 'rate_limiter'

def run_rate_limited(queue, limiter, delay, duration_ms)
  start_ms = java.lang.System.current_time_millis
  begin
    elapsed_ms = java.lang.System.current_time_millis - start_ms
    queue.push(elapsed_ms) unless limiter.limited?
    sleep(delay)
  end while elapsed_ms < duration_ms
  java.lang.System.current_time_millis - start_ms
end

def assert_within_percentage_margin(expected, actual, margin)
  eps = ((expected / 100.0) * margin).ceil
  assert_includes((expected-eps)..(expected+eps), actual.floor)
end

describe RateLimiter do
  it 'rate limits a single writer' do
    rate        = rand(1_000)
    queue       = []
    limiter     = RateLimiter.new(rate)
    duration_ms = run_rate_limited(queue, limiter, 0.0001, 10_000.0)
    actual_rate = queue.size / (duration_ms / 1000.0)

    assert_within_percentage_margin(rate, actual_rate, 10)
  end

  it 'rate limits concurrent writers' do
    rate      = rand(1_000)
    queue     = Queue.new
    durations = Queue.new
    limiter   = RateLimiter.new(rate)

    # Spawn a random number of threads, at least two.
    (2 + (rand(4).ceil)).times.map do
      Thread.new do
        durations.push(run_rate_limited(queue, limiter, 0.0001, 10_000.0))
      end
    end.each(&:join)

    # Pick the longest recorded duration.
    max_duration_ms = durations.size.times.map { durations.pop }.max
    actual_rate     = queue.size / (max_duration_ms / 1000.0)

    assert_within_percentage_margin(rate, actual_rate, 10)
  end
end
