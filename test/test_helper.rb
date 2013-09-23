require 'bundler/setup'

require 'simplecov'
SimpleCov.start

require 'harness'

require 'minitest/unit'
require 'minitest/autorun'

require 'webmock/minitest'

WebMock.disable_net_connect!

Thread.abort_on_exception = true

class FakeCollector
  Increment = Struct.new(:name, :amount, :rate)
  Decrement = Struct.new(:name, :amount, :rate)
  Gauge = Struct.new(:name, :value, :rate)

  attr_reader :gauges, :counters, :timers, :increments, :decrements

  def initialize
    @gauges, @counters, @timers, @increments, @decrements = [], [], [], [], []
  end

  def timing(*args)
    timers << Harness::Timer.new(*args)
  end

  def time(stat, sample_rate = 1)
    start = Time.now
    result = yield
    timing(stat, ((Time.now - start) * 1000).round, sample_rate)
    result
  end

  def increment(*args)
    increments << Increment.new(*args)
  end

  def decrement(*args)
    decrements << Decrement.new(*args)
  end

  def count(*args)
    counters << Harness::Counter.new(*args)
  end

  def gauge(*args)
    gauges << Gauge.new(*args)
  end
end

class MiniTest::Unit::TestCase
  def setup
    Harness.config.collector = FakeCollector.new
    Harness.config.queue = Harness::SynchronousQueue.new
  end

  def assert_timer(name)
    refute_empty timers
    timer = timers.find { |t| t.name == name }
    assert timer, "Timer #{name} not logged!"
  end

  def assert_increment(name)
    refute_empty increments
    increment = increments.find { |i| i.name == name }
    assert increment, "Increment #{name} not logged!"
  end

  def assert_decrement(name)
    refute_empty decrements
    decrement = decrements.find { |i| i.name == name }
    assert decrement, "decrement #{name} not logged!"
  end

  def assert_gauge(name)
    refute_empty gauges
    gauge = gauges.find { |g| g.name == name }
    assert gauge, "gauge #{name} not logged!"
  end

  def instrument(name, data = {}, &block)
    ActiveSupport::Notifications.instrument name, data, &block
  end

  def collector
    Harness.config.collector
  end

  def timers
    collector.timers
  end

  def increments
    collector.increments
  end

  def decrements
    collector.decrements
  end

  def counters
    collector.counters
  end

  def gauges
    collector.gauges
  end
end
