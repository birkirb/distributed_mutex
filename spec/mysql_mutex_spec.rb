require 'spec_helper'
require 'mysql_mutex'

describe MySQLMutex, 'with a lock on an open mysql connection' do

  before(:all) do
    ActiveRecord::Base.configurations = database_config
  end

  before(:each) do
    $output = ""
  end

  it 'should work with a synchronized block in one thread' do
    thread_1 = Thread.new do
      ActiveRecord::Base.establish_connection(:test)
      MySQLMutex.synchronize('test', 1) do
        $output += "1\n"
      end
    end
    thread_1.join
    $output.should == "1\n"
  end

  it 'should work with multible threads' do
    $output = Array.new
    threads = Array.new
    1.upto(3) do |number|
      threads << Thread.new(number) do |number|
        con = ActiveRecord::Base.mysql_connection(ActiveRecord::Base.configurations['test'])
        MySQLMutex.synchronize('test', 5, con) do
          $output << number
        end
      end
    end

    threads.each { |t| t.join }

    $output.sort.should == [1, 2, 3]
  end

  it 'should work with two excluding threads' do
    thread_1_mutex = nil
    thread_1 = Thread.new do
      con = ActiveRecord::Base.mysql_connection(ActiveRecord::Base.configurations['test'])
      thread_1_mutex = MySQLMutex.new('test', 1, false, con)
      $output += "1-RUN"
      $output += "-LOCK" if thread_1_mutex.lock
    end

    thread_1.join

    thread_2 = Thread.new do
      con = ActiveRecord::Base.mysql_connection(ActiveRecord::Base.configurations['test'])
      mutex = MySQLMutex.new('test', 1, false, con)
      $output += "-2-RUN"
      $output += "-LOCK" if mutex.lock
    end

    thread_2.join
    $output.should == "1-RUN-LOCK-2-RUN"
    thread_1_mutex.unlock.should == true
  end

  it 'should not be released by a nested lock on the same connection' do
    thread_1_mutex = nil
    thread_2_mutex = nil

    con = ActiveRecord::Base.mysql_connection(ActiveRecord::Base.configurations['test'])
    thread_1_mutex_1 = MySQLMutex.new('test', 1, false, con)

    thread_1_mutex_1.lock.should == true

    thread_1_mutex_2 = MySQLMutex.new('test', 1, false, con)

    thread_1_mutex_2.lock.should == true
    thread_1_mutex_2.unlock.should == true

    thread_2 = Thread.new do
      con = ActiveRecord::Base.mysql_connection(ActiveRecord::Base.configurations['test'])
      thread_2_mutex = MySQLMutex.new('test', 1, false, con)
      thread_2_mutex.lock.should == false # Should still be locked.
    end

    thread_2.join
    thread_1_mutex_1.unlock.should == true
  end

  it 'should not be released by a nested synchronized lock on the same connection' do
    con = ActiveRecord::Base.mysql_connection(ActiveRecord::Base.configurations['test'])
    sub_thread_executed = false
    MySQLMutex.synchronize('test', 1, true, con) do
      MySQLMutex.synchronize('test', 1, false, con) do
        sub_thread_executed = true
      end

      thread_2 = Thread.new do
        con = ActiveRecord::Base.mysql_connection(ActiveRecord::Base.configurations['test'])
        MySQLMutex.synchronize('test', 1, false, con) do
          fail
        end
      end
      thread_2.join
    end

    sub_thread_executed.should == true
  end

  it 'should released nested synchronized locks when an error occurs' do
    con = ActiveRecord::Base.mysql_connection(ActiveRecord::Base.configurations['test'])
    sub_thread_executed = false
    begin
        lambda do
          MySQLMutex.synchronize('test', 1, true, con) do
            MySQLMutex.synchronize('test', 1, false, con) do
              raise 'TestError'
              fail
            end
            fail
          end
        end.should raise_error(RuntimeError, 'TestError')

        thread_2 = Thread.new do
          con = ActiveRecord::Base.mysql_connection(ActiveRecord::Base.configurations['test'])
          MySQLMutex.synchronize('test', 1, false, con) do
            sub_thread_executed = true
          end
        end
        thread_2.join
    rescue => err
      fail(err)
    end

    sub_thread_executed.should == true
  end

  it 'should released nested synchronized locks and block a second thread which times out' do
    sub_thread_executed = false
    main_thread_completed = false
    final_thread_completed = false

    begin
      thread_2 = Thread.new do
        con = ActiveRecord::Base.mysql_connection(ActiveRecord::Base.configurations['test'])
        sleep 0.1
        MySQLMutex.synchronize('test', 1, true, con) do
          sub_thread_executed = true
        end
      end

      thread_1 = Thread.new do
        con = ActiveRecord::Base.mysql_connection(ActiveRecord::Base.configurations['test'])
        MySQLMutex.synchronize('test', 1, true, con) do
          MySQLMutex.synchronize('test', 1, true, con) do
            sleep 3
            main_thread_completed = true
          end
        end
      end

      lambda do
        thread_2.join
      end.should raise_error(MutexLockTimeout)

      thread_1.join

      con = ActiveRecord::Base.mysql_connection(ActiveRecord::Base.configurations['test'])
      MySQLMutex.synchronize('test', 1, true, con) do
        final_thread_completed = true
      end
    rescue => err
      fail(err)
    end

    sub_thread_executed.should == false
    main_thread_completed.should == true
    final_thread_completed.should == true
  end

  it 'should released nested synchronized locks throwing an error and block a second accessing before the error' do
    final_thread_completed = false

    begin
      thread_2 = Thread.new do
        con = ActiveRecord::Base.mysql_connection(ActiveRecord::Base.configurations['test'])
        sleep 0.1
        MySQLMutex.synchronize('test', 1, true, con) do
          raise 'Boom 2!'
        end
      end

      thread_1 = Thread.new do
        con = ActiveRecord::Base.mysql_connection(ActiveRecord::Base.configurations['test'])
        MySQLMutex.synchronize('test', 1, true, con) do
          MySQLMutex.synchronize('test', 1, true, con) do
            sleep 3
            raise 'Boom 1!'
          end
        end
      end

      lambda do
        thread_2.join
      end.should raise_error(MutexLockTimeout)

      lambda do
        thread_1.join
      end.should raise_error(RuntimeError, 'Boom 1!')

      con = ActiveRecord::Base.mysql_connection(ActiveRecord::Base.configurations['test'])
      MySQLMutex.synchronize('test', 1, true, con) do
        final_thread_completed = true
      end
    rescue => err
      fail(err)
    end

    final_thread_completed.should == true
  end

end
