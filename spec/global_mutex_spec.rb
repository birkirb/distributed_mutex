require 'spec_helper'
require 'global_mutex'

describe GlobalMutex, 'when created with a key and timeout' do

  it 'should give access to the key and timeout values' do
    mutex = GlobalMutex.new('test', 1)
    mutex.timeout.should == 1
    mutex.key.should == 'test'
  end

  it 'should allow querying on lock state' do
    mutex = GlobalMutex.new('test', 1)
    mutex.locked?.should == false
  end

  it 'should allow locking and unlocking and report the success or failure of these operations' do
    mutex = GlobalMutex.new('test', 1)
    mutex.lock.should == true
    mutex.locked?.should == true

    mutex_2 = GlobalMutex.new('test', 0)
    mutex_2.locked?.should == false
    mutex_2.lock.should == false
    mutex_2.locked?.should == false
    mutex_2.unlock.should == false

    mutex.unlock.should == true
    mutex.locked?.should == false

    mutex_2.lock.should == true
    mutex_2.locked?.should == true
    mutex.locked?.should == false
    mutex_2.unlock.should == true
    mutex_2.locked?.should == false
  end

  it 'should allow lock attempts and report the success or failure of the operation' do
    mutex = GlobalMutex.new('test', 1)
    mutex.try_lock.should == true
    mutex.locked?.should == false
  end

  it 'should allow locked operations in a block via #synchronize' do
    block_assigned_variable = 0

    mutex = GlobalMutex.new('test', 1)
    mutex.locked?.should == false
    success = mutex.synchronize do
      block_assigned_variable = 1
      mutex.locked?.should == true
    end
    success.should == true
    mutex.locked?.should == false
    block_assigned_variable.should == 1
  end

  it 'should report failed block operationds via #synchronize' do
    block_assigned_variable = 0

    mutex_locked = GlobalMutex.new('test', 1)
    mutex_locked.lock
    mutex_locked.locked?.should == true

    mutex = GlobalMutex.new('test', 1)
    mutex.locked?.should == false
    success = mutex.synchronize do
      block_assigned_variable = 1
    end

    success.should == false
    mutex.locked?.should == false
    block_assigned_variable.should == 0
    mutex_locked.unlock.should == true
  end

  it 'should pass up error in synchronize' do
    mutex = GlobalMutex.new('test', 1)
    lambda do
      mutex.synchronize do
        raise 'some_error'
      end
    end.should raise_error('some_error')
    mutex.locked?.should == false
  end

  it 'should wait until the timeout passes before giving up' do
    mutex_locked = GlobalMutex.new('test', 1)
    mutex_locked.lock

    time_start = Time.now
    mutex = GlobalMutex.new('test', 3)
    mutex.lock.should == false
    time_end = Time.now
    (time_end - time_start + 0.05).should > 3

    mutex_locked.unlock.should == true

    mutex = GlobalMutex.new('test', 3)
    mutex.lock.should == true
    mutex.unlock.should == true
  end

  it 'should throw an exception when so enabled on mutex timeout' do
    mutex_locked = GlobalMutex.new('test', 1)
    mutex_locked.lock

    mutex = GlobalMutex.new('test', 0, true)
    lambda { mutex.lock }.should raise_error(MutexLockTimeout, 'Mutex lock operation timed out')
    mutex.locked?.should == false
    mutex_locked.unlock.should == true
  end

end

describe GlobalMutex, 'when access via a class synchronized method' do

  it 'should use key and time values for direct access to the #synchronize' do
    block_assigned_variable = 0

    success = GlobalMutex.synchronize('test', 1) do
      GlobalMutex.new('test', 0).try_lock.should == false
      block_assigned_variable = 1
    end
    success.should == true
    block_assigned_variable.should == 1
    GlobalMutex.new('test', 0).try_lock.should == true
  end

end
