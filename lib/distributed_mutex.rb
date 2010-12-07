require 'mutex_lock_timeout'
require 'mutex_lock_release_failure'

class DistributedMutex < Mutex

  DEFAULT_TIMEOUT = 1
  DEFAULT_EXCEPTION_ON_TIMEOUT = false

  @@active_locks = Hash.new

  attr_reader :key, :timeout, :exception_on_timeout
  alias excluse_unlock unlock

  def initialize(key, timeout = DEFAULT_TIMEOUT, exception_on_timeout = DEFAULT_EXCEPTION_ON_TIMEOUT)
    @key = key
    @timeout = timeout
    @locked = false
    @exception_on_timeout = exception_on_timeout
  end

  def lock
    @locked = get_lock
    if true == @locked
      @@active_locks[@key] = timeout
      true
    else
      if @exception_on_timeout
        raise MutexLockTimeout.new
      else
        false
      end
    end
  end

  def locked?
    @locked
  end

  def synchronize(&block)
    if self.lock
      begin
        yield
      ensure
        self.unlock
      end
      true
    else
      false
    end
  end

  def try_lock
    was_locked = nil
    begin
      self.lock
      was_locked = locked?
    ensure
      self.unlock
    end
    was_locked
  end

  def unlock
    if locked?
      if release_lock
        @@active_locks.delete(@key)
        @locked = false
        true
      else
        raise MutexLockReleaseFailure
      end
    else
      false
    end
  end

  def self.synchronize(key, timeout = DEFAULT_TIMEOUT, exception_on_timeout = DEFAULT_EXCEPTION_ON_TIMEOUT, &block)
    mutex = new(key, timeout, exception_on_timeout)
    mutex.synchronize(&block)
  end

  def self.active_locks
    @@active_locks
  end

  private

  # Return true if and only if a lock is obtained
  def get_lock
    raise 'Method not implemented'
  end

  # Return true if and only if a lock is released
  def release_lock
    raise 'Method not implemented'
  end

end

at_exit do
  locks = DistributedMutex.active_locks
  if locks.size > 0
    if defined?(Rails)
      Rails.logger.error("MySQLMutex: Locks still active! - #{locks.inspect}")
    else
      STDERR.puts("MySQLMutex: Locks still active! - #{locks.inspect}")
    end
  else
    if defined?(Rails)
      Rails.logger.debug("MySQLMutex: All locks released.")
    else
      STDERR.puts("MySQLMutex: All locks released.")
    end
  end
end
