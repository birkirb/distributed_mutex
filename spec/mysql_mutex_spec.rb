require 'spec/spec_helper'
require 'lib/mysql_mutex'

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
    thread_1 = Thread.new do
      con = ActiveRecord::Base.mysql_connection(ActiveRecord::Base.configurations['test'])
      mutex = MySQLMutex.new('test', 1, con)
      $output += "1-RUN"
      $output += "-LOCK" if mutex.lock
    end

    thread_2 = Thread.new do
      con = ActiveRecord::Base.mysql_connection(ActiveRecord::Base.configurations['test'])
      mutex = MySQLMutex.new('test', 1, con)
      $output += "-2-RUN"
      $output += "-LOCK" if mutex.lock
    end

    thread_1.join
    thread_2.join
    $output.should == "1-RUN-LOCK-2-RUN"
  end

end
