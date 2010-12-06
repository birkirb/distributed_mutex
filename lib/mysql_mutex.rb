require 'active_record'
require 'distributed_mutex'

class MySQLMutex < DistributedMutex

  @active_locks = Hash.new

  def initialize(key, timeout = DEFAULT_TIMEOUT, exception_on_timeout = DEFAULT_EXCEPTION_ON_TIMEOUT, connection = ActiveRecord::Base.connection)
    @connection = connection
    @lock_was_free = false
    @get_sql = ActiveRecord::Base.send(:sanitize_sql_array,["SELECT IS_FREE_LOCK(?), GET_LOCK(?,?)", key, key, timeout])
    @release_sql = ActiveRecord::Base.send(:sanitize_sql_array,["SELECT RELEASE_LOCK(?)", key])
    super(key, timeout, exception_on_timeout)
  end

  def self.active_locks
    @active_locks
  end

  def self.synchronize(key, timeout = DEFAULT_TIMEOUT, exception_on_timeout = DEFAULT_TIMEOUT, con = ActiveRecord::Base.connection, &block)
    mutex = new(key, timeout, exception_on_timeout, con)
    @active_locks[key] = timeout
    mutex.synchronize(&block)
    @active_locks.delete(key)
  end

  private

  def get_lock
    is_free_lock, get_lock = @connection.select_rows(@get_sql).first
    @lock_was_free = ('1' == is_free_lock)
    '1' == get_lock
  end

  def release_lock
    if @lock_was_free
      '1' == @connection.select_value(@release_sql)
    else
      true
    end
  end

end

at_exit do
  locks = MySQLMutex.active_locks
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
