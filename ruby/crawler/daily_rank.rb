require 'open-uri'
require 'date'

class DailyRank
  def initialize(y, m, d)
    raise ArgumentError if !Date.valid_date?(y, m, d)
    @date = Date.new(y, m, d);
    @url = sprintf("http://b.hatena.ne.jp/hotentry?mode=daily&date=%04d%02d%02d", y, m, d)
    @cache = sprintf("daily/%04d%02d%02d.txt", y, m, d)
    @entries = []
  end

  attr_accessor :date, :url, :cache, :entries

  def load
    if File.exist?(@cache)
      self::load_cache
    else
      self::load_url
    end
    self
  end
  
  def load_url
    @entries = []
    print "load url: #{@url}\n"
    open(@url) {|f|
      f.read.split('<div class="entry-body">')[1 .. -1].each {|entry|
        #<a href="url" class="bookmark" target="_blank">title</a>
        if (/<a href="([^"]+)"[^>]+>([^<]+)<\/a>/m =~ entry) then
          url, title = $1, $2
          @entries.push({:url => url.gsub("&amp;", "&"), :title => title.gsub("&amp;", "&")})
        end
      }
    }
    #self::save_to_cache if @entries.length > 0
    @entries
  end

  def load_cache
    return false if !File.exist?(@cache)

    @entries = []
    File.open(@cache) {|f|
      f.each {|line|
        url, title = line.chomp.split("\t")
        @entries.push({:url => url, :title => title}) if url && title
      }
    }
    @entries
  end
  
  def dump
    @entries.map {|entry|
      entry[:url] + "\t" + entry[:title]
    }.join("\r\n")
  end

  def save_to_cache
    File.open(@cache + "_", "w") {|f|
      f.puts(self::dump)
    }
    File.rename(@cache + "_", @cache)
  end
end
