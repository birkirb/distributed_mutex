require 'rubygems'
require 'spec'

#require 'lib/mysql_mutex'
def database_config
  YAML.load_file('spec/config/database.yml')
end
