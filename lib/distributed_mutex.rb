class DistributedMutex < Mutex

  DEFAULT_TIMEOUT = 1

  attr_reader :key, :timeout
  alias excluse_unlock unlock

  def initialize(key, timeout = DEFAULT_TIMEOUT)
    @key = key
    @timeout = timeout
    @locked = false
  end

  def lock
    @locked = get_lock
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
    begin
      self.lock
      was_locked = locked?
      was_locked
    ensure
      self.unlock
    end
  end

  def unlock
    if @locked
      if release_lock
        @locked = false
        true
      else
        false
      end
    else
      false
    end
  end

  def self.synchronize(key, timeout = DEFAULT_TIMEOUT, &block)
    mutex = new(key, timeout)
    mutex.synchronize(&block)
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
