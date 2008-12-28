require 'optparse'
require 'rubygems'
require 'sqlite3'
require 'crawler/entry'
require 'crawler/daily_rank'

$db = SQLite3::Database.new('hatebu_nenkan.db')
$stu = $db.prepare("select user from bookmarks where entry_id = ?")
$stb = $db.prepare("insert into bookmarks(entry_id,user,time,commented) values(?,?,?,?)")
$stt = $db.prepare("insert into bookmarktags(bookmark_id,tag_id) values(?,?)")
$st_tag_select = $db.prepare("select id from tags where name = ?")
$st_tag_insert = $db.prepare("insert into tags(name) values(?)")

def update_entry(url, entry)
  entry_id, last_update = $db.execute("select id,last_update from entries where url = ?", url).flatten
  if entry_id.nil? then
    $db.execute("insert into entries (eid,url,title,last_update)" +
                "values(?,?,?,?)",
                entry.bid, url, entry.title,
                entry.time.strftime("%Y-%m-%d %H:%M:%S"))
    return $db.last_insert_row_id
  else
    return entry_id unless last_update.nil?

    $db.execute("update entries " + 
                "set eid=?,url=?,title=?,last_update=? where id=?",
                entry.bid, url, entry.title,
                entry.time.strftime("%Y-%m-%d %H:%M:%S"),
                entry_id)
  end
  return entry_id
end

# insert tag
def add_tag(tags, id)
  # bookmark_id, tag
  tags.each do |tag|
    tag_id = $st_tag_select.execute(tag).next
    if tag_id.nil? then
      $st_tag_insert.execute(tag)
      tag_id = $db.last_insert_row_id
    else
      tag_id = tag_id.flatten[0]
    end
    $stt.execute(id, tag_id)
  end
end

# insert bookmark
def add_bookmark(entry_id, bookmark)
  $stb.execute(entry_id, bookmark[:id],
               bookmark[:time].strftime("%Y-%m-%d %H:%M:%S"),
               !bookmark[:desc].nil? && bookmark[:desc] != "")
  add_tag(bookmark[:tags], $db.last_insert_row_id)
end

def get_bookmark_users(entry_id)
  return $stu.execute(entry_id).inject({}) { |obj,row| obj[row[0]]=1; obj}
end

def register_entry(url)
  entry = Entry.new(url)
  entry.load

  entry_id = update_entry(url, entry)
  users = get_bookmark_users(entry_id)

  added = false
  entry.bookmarks.each do |bookmark|
    next if users[bookmark[:id]]
    add_bookmark(entry_id, bookmark)
    added = true
  end
  return added
end


start = nil
count = 9999999

opt = OptionParser.new
opt.on('-s=VAL', '--start_id=VAL', 'Start id') {|v| start = v}
opt.on(nil, '--from_file', 'Not from db, from file') {|v| from_file = v}
opt.on('-c=VAL', '--count=VAL', 'Count') {|v| count = v.to_i}
opt.parse! ARGV
from_file = !from_file.nil?


if from_file then
  entries = $db.execute("select url from entries where id >= ?;", start).flatten
else
  entries = []
  start = start || "2005-02-10"
  p start
  Date.parse(start).upto(Date.today - 1) do |date|
    rank = DailyRank.new(date.year, date.month, date.day)
    rank.load
    entries += rank.entries.map {|entry| entry[:url]}
  end
end
entries = entries.uniq[0 .. count]

i = 0
entries.each do |url|
  i += 1
  print "#{i}: #{url}\t"
  $stdout.flush

  added = false
  $db.transaction do |db| added = register_entry(url) end
  #register_entry(url)
  print added ? " OK\n" : " Skip\n"
end
