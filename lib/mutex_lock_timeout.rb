class MutexLockTimeout < StandardError

  def message
    'Mutex lock operation timed out'
  end
end
