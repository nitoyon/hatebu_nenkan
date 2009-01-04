require 'crawler/daily_rank'

#-----------------

Date.new(2005, 2, 10).upto(Date.today - 1) {|date|
  _start = Time.now
  print date.to_s + "\t"

  rank = DailyRank.new(date.year, date.month, date.day)
  if !File.exist? rank.cache
    rank.load
    print "OK\n"
    _end = Time.now
    sleep([5 - (_end - _start), 0].max)
  else
    print "Skip\n"
  end
}

