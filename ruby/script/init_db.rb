require 'optparse'
require 'date'
require 'db/connect'
require 'db/EntrySchema'

up = true

year = 2005
opt = OptionParser.new
opt.on('-y=VAL', '--year=VAL', 'set year') {|v| year = v}
opt.on('-clear', '--clear', 'clear db') {|v| up = false}
opt.parse! ARGV

year = year.to_i
p year
abort("invalid year\n") if year < 2005 || year > Date.today.year
print("year: #{year}\n")
print(up ? "create db\n" : "drop db\n")

connect(year)
if(up) then
  Sql::EntrySchema.migrate(:up)
else
  Sql::EntrySchema.migrate(:down)
end

  
