
require 'summary'


#------------------

def get_summary(period, start, goal)
  date = start
  while(date <= goal)
    print date.to_s + "\n"
    
    summary = Summary.new(period, date)
    if !File.exist? (summary.getFilename + "domain.txt") || !File.exist?(summary.getFilename + "count.txt") then
      s = summary.exec2
      summary.dump_domain(s)
      summary.dump(s)
    end
    
    if period == 'monthly'
      date = date >> 1
    else
      date = Date.new(date.year + 1, 1, 1)
    end
  end
end
  
date = Date.new(2005, 2)
#date = Date.new(2006, 1)
thismonth = Date.today - Date.today.day + 1
thisyear = Date.new(thismonth.year, 1, 1)


get_summary('monthly', date, thismonth)
get_summary('yearly', date, thisyear)
