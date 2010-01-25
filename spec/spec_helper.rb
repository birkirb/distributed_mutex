require 'rubygems'
require 'spec'

$:.unshift "#{File.dirname(__FILE__)}/../lib"

def database_config
  YAML.load_file('spec/config/database.yml')
end
