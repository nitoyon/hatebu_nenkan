require 'rubygems'
require 'active_record'

def connect(year)
  ActiveRecord::Base.remove_connection if ActiveRecord::Base.connected?
  ActiveRecord::Base.establish_connection(
                                          :adapter => 'sqlite3',
                                          :dbfile => "hatebu_nenkan#{year.to_s}.db"
                                          )
end
