require 'optparse'
require 'db/connect'
require 'db/EntrySchema'

up = true

opt = OptionParser.new
opt.on('-clear', '--clear', 'clear db') {|v| up = false}
opt.parse! ARGV

print(up ? "create db\n" : "drop db\n")

if(up) then
  Sql::EntrySchema.migrate(:up)
else
  Sql::EntrySchema.migrate(:down)
end

  
