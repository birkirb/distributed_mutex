require 'active_record'
require 'distributed_mutex'

class MySQLMutex < DistributedMutex

  def initialize(key, timeout = DEFAULT_TIMEOUT, exception_on_timeout = DEFAULT_EXCEPTION_ON_TIMEOUT, connection = ActiveRecord::Base.connection)
    @connection = connection
    @lock_was_free = false
    @get_sql = ActiveRecord::Base.send(:sanitize_sql_array,["SELECT IS_FREE_LOCK(?), GET_LOCK(?,?)", key, key, timeout])
    @release_sql = ActiveRecord::Base.send(:sanitize_sql_array,["SELECT RELEASE_LOCK(?)", key])
    super(key, timeout, exception_on_timeout)
  end

  def self.synchronize(key, timeout = DEFAULT_TIMEOUT, con = ActiveRecord::Base.connection, &block)
    mutex = new(key, timeout, con)
    mutex.synchronize(&block)
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
      false
    end
  end

end
