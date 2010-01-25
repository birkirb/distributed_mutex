require 'active_record'
require 'lib/distributed_mutex'

class MySQLMutex < DistributedMutex

  def initialize(key, timeout = DEFAULT_TIMEOUT, connection = ActiveRecord::Base.connection)
    @connection = connection
    @get_sql = ActiveRecord::Base.send(:sanitize_sql_array,["SELECT GET_LOCK(?,?)", key, timeout])
    @release_sql = ActiveRecord::Base.send(:sanitize_sql_array,["SELECT RELEASE_LOCK(?)", key])
    super(key, timeout)
  end

  def self.synchronize(key, timeout = DEFAULT_TIMEOUT, con = ActiveRecord::Base.connection, &block)
    mutex = new(key, timeout, con)
    mutex.synchronize(&block)
  end

  private

  def get_lock
    '1' == @connection.select_value(@get_sql)
  end

  def release_lock
    '1' == @connection.select_value(@release_sql)
  end

end
