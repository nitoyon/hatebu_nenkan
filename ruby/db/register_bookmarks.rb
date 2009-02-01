require 'optparse'
require 'rubygems'
require 'sqlite3'
require 'db/connect_raw'
require 'crawler/entry'
require 'crawler/daily_rank'
require 'time'

def init_db_statement(year)
  $stt.each_value do |stt| stt.close  end unless $stt.nil?
  print "open db: #{year}\n"
  connect_raw(year)

  $stt = {}
  $stt['users'] = $db.prepare("select user from bookmarks where entry_id = ?")
  $stt['bookmark'] = $db.prepare("insert into bookmarks(entry_id,user,time,comment) values(?,?,?,?)")
  $stt['tag'] = $db.prepare("insert into bookmarktags(bookmark_id,tag_id) values(?,?)")
  $stt['tag_select'] = $db.prepare("select id from tags where name = ?")
  $stt['tag_insert'] = $db.prepare("insert into tags(name) values(?)")
end

def update_entry(url, entry)
  entry_id, last_update = $db.execute("select id,last_update from entries where url = ?", url).flatten
  if entry_id.nil? then
    $db.execute("insert into entries (eid,url,title,last_update)" +
                "values(?,?,?,?)",
                entry.bid, url, entry.title,
                entry.time.strftime("%Y-%m-%d %H:%M:%S"))
    return $db.last_insert_row_id
  else
    #return entry_id unless last_update.nil?
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
    tag_id = $stt['tag_select'].execute(tag).next
    if tag_id.nil? then
      $stt['tag_insert'].execute(tag)
      tag_id = $db.last_insert_row_id
    else
      tag_id = tag_id.flatten[0]
    end
    $stt['tag'].execute(id, tag_id)
  end
end

# insert bookmark
def add_bookmark(entry_id, bookmark)
  $stt['bookmark'].execute(entry_id, bookmark[:id],
               bookmark[:time].strftime("%Y-%m-%d %H:%M:%S"),
               bookmark[:desc])
  add_tag(bookmark[:tags], $db.last_insert_row_id)
end

def get_bookmark_users(entry_id)
  return $stt['users'].execute(entry_id).inject({}) do |obj,row|
    obj[row[0]]=1; obj
  end
end

def register_entry(url, year)
  entry = Entry.new(url)
  entry.load

  entry_id = update_entry(url, entry)
  users = get_bookmark_users(entry_id)

  added = false
  entry.bookmarks.each do |bookmark|
    next if users[bookmark[:id]] or bookmark[:time].year != year
    add_bookmark(entry_id, bookmark)
    added = true
  end
  return added
end


start = 2005
count = 9999999
modified = Time.at(0)

opt = OptionParser.new
opt.on('-s=VAL', '--start_year=VAL', 'Start year') {|v| start = v.to_i}
opt.on(nil, '--from_file', 'Not from db, from file') {|v| $from_file = v}
opt.on('-c=VAL', '--count=VAL', 'Count') {|v| count = v.to_i}
opt.on('-m=VAL', '--modified=VAL', 'If modified since') {|v| modified = Time.parse(v)}
opt.parse! ARGV
$from_file = !$from_file.nil?

print("count:      #{count}\n")
print("start year: #{start}\n")
print("modified:   #{modified.to_s}\n")
print("\n")

def get_entries_in(year)
  if !$from_file then
    entries = $db.execute(<<SQL, Date.new(year).to_s, Date.new(year + 1).to_s).flatten
select E.url from dailyranks DR
    join entries E on DR.entry_id=E.id
    where DR.date >= date(?) and DR.date < date(?)
    group by DR.entry_id order by E.id;
SQL
  else
    entries = []
    Date.new(year).upto(Date.new(year + 1) - 1) do |date|
      break if date >= Date.today - 1
      rank = DailyRank.new(date.year, date.month, date.day)
      rank.load
      entries += rank.entries.map {|entry| entry[:url]}
    end
  end
  entries = entries.uniq
end

start.upto(Date.today.year) do |year|
  init_db_statement(year)

  get_entries_in(year).each do |url|
    _start = Time.now

    print "#{url}\t"
    $stdout.flush

    last_update = $db.execute("select last_update from entries where url = ?", url).flatten[0]
    if !last_update.nil? && Time.parse(last_update) > modified then
      print "Skip\n"
      next
    end

    added = false
    $db.transaction do |db| added = register_entry(url, year) end
    print added ? "OK\n" : "Skip\n"

    _end = Time.now
    sleep([5 - (_end - _start), 0].max)
  end
end
