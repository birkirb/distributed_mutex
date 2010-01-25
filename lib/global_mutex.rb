require 'lib/distributed_mutex'

# Simple global variable mutex, not production quality more
# as a test implementation for the super class.
class GlobalMutex < DistributedMutex

  private

  def get_lock
    if @timeout && @timeout > 1
      1.upto(@timeout) do
        if set_global_mutex
          return true
        else
          sleep(1)
        end
      end
    end
    return set_global_mutex
  end

  def release_lock
    eval("$#{@key} = nil")
    true
  end

  def set_global_mutex
    if nil == eval("$#{@key}")
      eval("$#{@key} = 1")
      true
    else
      false
    end
  end

end
