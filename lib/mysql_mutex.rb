require 'active_record'
require 'distributed_mutex'

class MySQLMutex < DistributedMutex

  @@thread_locks = Hash.new { |h,k| h[k] = Hash.new(0) } # Accounting for nested locks.

  def initialize(key, timeout = DEFAULT_TIMEOUT, exception_on_timeout = DEFAULT_EXCEPTION_ON_TIMEOUT, connection = ActiveRecord::Base.connection)
    super(key, timeout, exception_on_timeout)
    @connection = connection
    @connection_id = connection.show_variable('pseudo_thread_id')
    @get_sql = ActiveRecord::Base.send(:sanitize_sql_array,["SELECT GET_LOCK(?,?)", key, timeout])
    @release_sql = ActiveRecord::Base.send(:sanitize_sql_array,["SELECT RELEASE_LOCK(?)", key])
  end

  def self.synchronize(key, timeout = DEFAULT_TIMEOUT, exception_on_timeout = DEFAULT_TIMEOUT, con = ActiveRecord::Base.connection, &block)
    mutex = new(key, timeout, exception_on_timeout, con)
    mutex.synchronize(&block)
  end

  def self.active_locks
    @@thread_locks
  end

  private

  def get_lock
    if thread_lock_count > 0
      increment_thread_lock_count
      true
    else
      get_lock = @connection.select_value(@get_sql)

      if defined?(Rails)
        Rails.logger.debug("MySQLMutex: GET_LOCK=#{get_lock}")
      end

      if '1' == get_lock.to_s
        increment_thread_lock_count
        true
      else
        false
      end
    end
  end

  def release_lock
    if thread_lock_count > 1
      decrement_thread_lock_count
      true
    elsif thread_lock_count > 0
      lock_release = @connection.select_value(@release_sql)

      if defined?(Rails)
        Rails.logger.debug("MySQLMutex: RELEASE_LOCK=#{lock_release}")
      end

      if '1' == lock_release.to_s
        decrement_thread_lock_count
        true
      else
        false
      end
    else
      false
    end
  end

  def thread_lock_count
    @@thread_locks[@connection_id][self.key]
  end

  def increment_thread_lock_count
    @@thread_locks[@connection_id][self.key] += 1
  end

  def decrement_thread_lock_count
    @@thread_locks[@connection_id][self.key] -= 1

    if 0 == @@thread_locks[@connection_id][self.key]
      @@thread_locks[@connection_id].delete(self.key)
    end
  end

end

# at_exit do
#   rails_logger = defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
#   begin
#     locks = MySQLMutex.active_locks
#     locks.delete_if do |k, v|
#       v.empty?
#     end
#
#     if locks.size > 0
#       if rails_logger
#         rails_logger.error("MySQLMutex: Locks still active! - #{locks.inspect}")
#       else
#         STDERR.puts("MySQLMutex: Locks still active! - #{locks.inspect}")
#       end
#     end
#   rescue => err
#     if rails_logger
#       rails_logger.error("MySQLMutex: #{err.message}")
#     else
#       STDERR.puts("MySQLMutex: #{err.message}")
#     end
#   end
# end
