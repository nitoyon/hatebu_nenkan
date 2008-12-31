require 'optparse'
require 'sqlite3'
require 'db/connect_raw'


$SQL_TAG = <<SQL
select lower(T.name),count(T.id) from 
  (select distinct DR.entry_id as entry_id from dailyranks as DR
      where DR.date >= date(?) and DR.date < date(?)
  ) as RE
  join bookmarks B on 
    RE.entry_id = B.entry_id
      and
    B.time >= date(?) and B.time < date(?)
  join bookmarktags BT on
    B.id = BT.bookmark_id
  join tags T on
    BT.tag_id = T.id
  group by lower(T.name) order by count(T.id) desc limit 30;
SQL

$SQL_URL = <<SQL
select E.url,E.title,R.count from
  entries E,
  (select B.entry_id as entry_id,count(B.id) as count from 
    (select distinct DR.entry_id as entry_id from dailyranks DR
        where DR.date >= date(?) and DR.date < date(?)
    ) as RE
    join bookmarks as B on 
      B.entry_id = RE.entry_id
        and
      B.time >= date(?) and B.time < date(?)
    group by B.entry_id order by count(B.id) desc limit ?
  ) R
  where E.id = R.entry_id;
SQL


def update_url(fn, cur_date, next_date)
  return if File.exist? fn
  result = $db.execute($SQL_URL,
                       cur_date.to_s, next_date.to_s,
                       cur_date.to_s, next_date.to_s,
                       30)
  File.open(fn, "w") do |f|
    result.each do |e|
      f.puts e.join("\t")
    end
  end
end

def get_domain(url)
  return url.sub(%r|https?://([^/]+).*|, '\1')  
end

def update_domain(fn, cur_date, next_date)
  return if File.exist? fn
  result = $db.execute($SQL_URL,
                       cur_date.to_s, next_date.to_s,
                       cur_date.to_s, next_date.to_s,
                       9999999)
  domain = {}
  result.each do |r|
    d = get_domain(r[0])
    domain[d] ||= 0
    domain[d] += r[2].to_i
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
                       cur_date.to_s, next_date.to_s,
                       cur_date.to_s, next_date.to_s)
  File.open(fn, "w") do |f|
    result[0 .. 30].each do |e|
      f.puts e.join("\t")
    end
  end
end

def get_summary(period, start, goal)
  date = start
  while(date <= goal)
    print "#{date.to_s}\n"
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
end_date = Date.today.to_s
$quite = false
opt = OptionParser.new
opt.on('-s=VAL', '--start=VAL', 'Start date') {|v| start_date = v}
opt.on('-e=VAL', '--end=VAL', 'End date') {|v| end_date = v}
opt.on('-q', '--quite', 'Quite mode') {|v| $quite = true}
opt.parse! ARGV

print("start date: #{start_date}\n")
print("end date: #{end_date}\n")
print("quite: #{$quite ? 'yes' : 'no'}\n")
start_date = Date.parse(start_date)
end_date = Date.parse(end_date)

endmonth = end_date - end_date.day + 1
endyear = Date.new(end_date.year, 1, 1)

get_summary('monthly', start_date, endmonth)
get_summary('yearly', start_date, endyear)
