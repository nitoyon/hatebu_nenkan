require 'optparse'
require 'sqlite3'
require 'db/connect_raw'


$SQL_TAG = <<SQL
select lower(name),count(tag_id) 
  from bookmarktags join tags 
    on 
      bookmark_id in 
        (select distinct id from bookmarks
          where
            entry_id in (select distinct entry_id from dailyranks
              where date >= ? and date < ?
            )
              and 
            time >= ? and time < ?
        )
        and
      tags.id = tag_id
  group by lower(name) order by count(tag_id) desc;
SQL

$SQL_URL = <<SQL
select url,title,count(entry_id)
  from entries join bookmarks
    on
      entry_id in (select distinct entry_id from dailyranks
        where date >= date(?) and date < date(?)
      )
        and
      time >= date(?) and time < date(?)
        and
      entry_id = entries.id
  group by entry_id order by count(entry_id) desc;
SQL

$SQL_DOMAIN = <<SQL
select url,count(entry_id)
  from entries join bookmarks
    on
      entry_id in (select distinct entry_id from dailyranks
        where date >= date(?) and date < date(?)
      )
        and
      time >= date(?) and time < date(?)
        and
      entry_id = entries.id
  group by entry_id order by url;
SQL


class Date
  def to_db
    return strftime("%Y-%m-%d")
  end
end

def update_url(fn, cur_date, next_date)
  return if File.exist? fn
  result = $db.execute($SQL_URL,
                       cur_date.to_db, next_date.to_db,
                       cur_date.to_db, next_date.to_db)
  File.open(fn, "w") do |f|
    result[0 .. 30].each do |e|
      f.puts e.join("\t")
    end
  end
end

def get_domain(url)
  return url.sub(%r|https?://([^/]+).*|, '\1')  
end

def update_domain(fn, cur_date, next_date)
  return if File.exist? fn
  result = $db.execute($SQL_DOMAIN,
                       cur_date.to_db, next_date.to_db,
                       cur_date.to_db, next_date.to_db)
  domain = {}
  result.each do |r|
    d = get_domain(r[0])
    domain[d] ||= 0
    domain[d] += r[1].to_i
  end
  domain_rank = domain.keys.sort{|a,b| domain[b]<=>domain[a]}
  
  File.open(fn, "w") do |f|
    domain_rank[0 .. 30].each do |d|
      f.puts "#{d}\t#{domain[d]}"
    end
  end
end

def update_tag(fn, cur_date, next_date)
  return if File.exist? fn
  result = $db.execute($SQL_TAG,
                       cur_date.to_db, next_date.to_db,
                       cur_date.to_db, next_date.to_db)
  File.open(fn, "w") do |f|
    result[0 .. 30].each do |e|
      f.puts e.join("\t")
    end
  end
end

def get_summary(period, start, goal)
  date = start
  while(date <= goal)
    print "#{date.to_db}\n"
    cur_date = date
    next_date = date = (period == 'monthly' ?
                        date >> 1 :
                        Date.new(date.year + 1, 1, 1))
    date = next_date
    fn = (period == 'monthly' ?
          sprintf("summary/%04d%02d", cur_date.year, cur_date.month) :
          sprintf("summary/%04d", cur_date.year))

    update_url("#{fn}-count.txt", cur_date, next_date)
    print " - url\n"
    update_tag("#{fn}-tag.txt", cur_date, next_date)
    print " - tag\n"
    update_domain("#{fn}-domain.txt", cur_date, next_date)
    print " - domain\n\n"
  end
end



start_date = "2005-02-01"
$quite = false
opt = OptionParser.new
opt.on('-s=VAL', '--start=VAL', 'Start date') {|v| start_date = v}
opt.on('-q', '--quite', 'Quite mode') {|v| $quite = true}
opt.parse! ARGV

print("start date: #{start_date}\n")
print("quite: #{$quite ? 'yes' : 'no'}\n")
start_date = Date.parse(start_date)

thismonth = Date.today - Date.today.day + 1
thisyear = Date.new(thismonth.year, 1, 1)

get_summary('monthly', start_date, thismonth)
get_summary('yearly', start_date, thisyear)
