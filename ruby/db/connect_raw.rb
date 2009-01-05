require 'sqlite3'

def connect_raw(year)
  p $db.nil?
  $db.close if !$db.nil? && !$db.closed?
  $db = SQLite3::Database.new("hatebu_nenkan#{year.to_s}.db")
end
