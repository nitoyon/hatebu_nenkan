require 'rubygems'
require 'active_record'

ActiveRecord::Base.establish_connection(
                                        :adapter => 'sqlite3',
                                        :dbfile => 'hatebu_nenkan.db'
                                        )
