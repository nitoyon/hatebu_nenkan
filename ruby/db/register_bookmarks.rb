require 'rubygems'
require 'sqlite3'
require 'crawler/entry'

$db = SQLite3::Database.new('hatebu_nenkan.db')
$stu = $db.prepare("select user from bookmarks where entry_id = ?")
$stb = $db.prepare("insert into bookmarks(entry_id,user,time,commented) values(?,?,?,?)")
$stt = $db.prepare("insert into bookmarktags(bookmark_id,tag_id) values(?,?)")
$st_tag_select = $db.prepare("select id from tags where name = ?")
$st_tag_insert = $db.prepare("insert into tags(name) values(?)")

def update_entry(url, entry)
  entry_id, last_update = $db.execute("select id,last_update from entries where url = ?", url).flatten
  raise "entry data not found: #{url}" if entry_id.nil?
  return unless last_update.nil?

  $db.execute("update entries " + 
             "set eid=?,url=?,title=?,last_update=? where id=?",
              entry.bid, url, entry.title,
              entry.time.strftime("%Y-%m-%d %H:%M:%S"),
              entry_id)
  return $db.last_insert_row_id
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

def register(entry_id, url)
  users = get_bookmark_users(entry_id)

  entry = Entry.new(url)
  entry.load

  cur = Time.now
  update_entry(url, entry)

  added = false
  cur = Time.now
  entry.bookmarks.each do |bookmark|
    next if users[bookmark[:id]]
    add_bookmark(entry_id, bookmark)
    added = true
  end
  return added
end


start = (ARGV[0] || "0").to_i
count = (ARGV[1] || "9999999").to_i

i = 0
$db.execute("select id,url from entries where id >= ?;", start) do |entry|
  print "#{entry[0]}: #{entry[1]}\t"
  $stdout.flush

  added = false
  $db.transaction do |db| added = register(entry[0], entry[1]) end
  #register(entry[0], entry[1])
  print added ? " OK\n" : " Skip\n"
  i += 1
  exit if i >= count
end
