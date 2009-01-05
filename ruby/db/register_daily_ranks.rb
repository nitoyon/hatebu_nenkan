require 'optparse'
require 'rubygems'
require 'db/connect'
require 'db/EntrySchema'
require 'crawler/daily_rank'
require 'crawler/entry'

def register_entry_rank(date, rank, url)
  entry = Sql::Entry.find_by_url(url)
  if entry.nil? then
    entry = Sql::Entry.new do |e|
      e.url = url
    end
    entry.save
    print "#{url} registerd: #{entry.id}\n" unless $quite
  else
    #print "#{url}: #{entry.id}\n"
  end
  
  rank = Sql::Dailyrank.new do |r|
    r.date = date
    r.rank = rank
    r.entry_id = entry.id
  end
  rank.save
end

start_date = "2005-02-10"
$quite = false
opt = OptionParser.new
opt.on('-s=VAL', '--start=VAL', 'Start date') {|v| start_date = v}
opt.on('-q', '--quite', 'Quite mode') {|v| $quite = true}
opt.parse! ARGV

print("start date: #{start_date}\n")
print("quite: #{$quite ? 'yes' : 'no'}\n")
start_date = Date.parse(start_date)

year = nil
start_date.upto(Date.today - 1) do |date|
  connect(date.year) if date.year != year
  year = date.year
  
  date_str = date.strftime("%Y-%m-%d")
  ranks = Sql::Dailyrank.find_by_date(date_str)
  if !ranks.nil? then
    print "#{date_str} pass\n"
  else
    rank = DailyRank.new(date.year, date.month, date.day)
    rank.load
    i = 1
    Sql::Dailyrank.transaction do
      rank.entries.each do |e|
        register_entry_rank(date_str, i, e[:url])
        i += 1
      end
    end
    print "#{date_str} save\n"
  end
end
