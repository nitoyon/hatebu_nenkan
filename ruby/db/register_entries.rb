require 'rubygems'
require 'sqlite3'
require 'crawler/daily_rank'
require 'crawler/entry'

$db = SQLite3::Database.new('hatebu_nenkan.db')
$st_select_entry_id = $db.prepare("select id from entries where url = ?")
$st_insert_entry = $db.prepare("insert into entries(eid,url,title,last_update) values (?,?,?,?)")

def register_entry(url)
  id = $st_select_entry_id.execute(url)
  if(id.next) then
#    print url + " Skip\n"
    return
  end

  entry = Entry.new(url)
  entry.load

  $st_insert_entry.execute(entry.bid, url, entry.title, entry.time.strftime("%Y-%m-%d %H:%M:%S"))
#  print url + " OK\n"
end

count = (ARGV[0] || "50").to_i
print sprintf("count: %d\n", count)

date = (ARGV[1] || '2005-02-10')

#-----------------

Date.parse(date).upto(Date.today - 1) do |date|
  _start = Time.now
  print "\n" + date.to_s + "\n"

  rank = DailyRank.new(date.year, date.month, date.day)
  next unless File.exist? rank.cache
  rank.load

  $db.transaction do |db|
    rank.entries[0 .. count - 1].each {|entry|
      register_entry(entry[:url])
    }
  end
end



