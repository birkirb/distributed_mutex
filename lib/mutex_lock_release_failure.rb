class MutexLockReleaseFailure < StandardError

  def message
    'Failed to release Mutex lock. This should be regarded as a system bug.'
  end
end
