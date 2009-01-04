require 'optparse'
require 'crawler/entry'
require 'crawler/daily_rank'


count = 10
date = '2005-02-10'
modified = '2005-02-10'
verbose = false

opt = OptionParser.new
opt.banner = 'Usage: $ ruby get_top_entries.rb'
opt.on('-l=VAL', '--length=VAL', 'Get length') {|v| count = v.to_i}
opt.on('-s=VAL', '--start=VAL', 'Start date') {|v| date = v}
opt.on('-m=VAL', '--modified=VAL', 'If modified since') {|v| modified = v}
opt.on('-v', '--verbose', 'Output verbose') {|v| verbose = v}
opt.parse! ARGV

if verbose then
  print("count:      #{count}\n")
  print("start date: #{date}\n")
  print("modified:   #{modified}\n")
  print("verbose:    #{verbose}\n")
end
modified = Time.parse(modified)

#-----------------

Date.parse(date).upto(Date.today - 1) do |date|
  _start = Time.now
  print "\n" + date.to_s + "\n"

  rank = DailyRank.new(date.year, date.month, date.day)
  next unless File.exist? rank.cache
  rank.load

  rank.entries[0 .. count - 1].each {|entry|
    _start = Time.now

    print entry[:url] + "\t"
    STDOUT.flush
    begin
      e = Entry.new(entry[:url])
      e.load(modified)
    rescue
      STDERR.puts "Warning: #$!\n"
      sleep(10)
      retry
    end

    if (e.using_cache)
      print "Pass (" + e.bookmarks.length.to_s + ")\n"
    else
      print "OK (" + e.bookmarks.length.to_s + ")\n"
      _end = Time.now
      sleep([5 - (_end - _start), 0].max)
    end
  }
end

