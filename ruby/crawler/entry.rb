#! ruby -Ku

require 'open-uri'
require 'digest/md5'
require 'date'
require 'rexml/document'
require 'parsedate'
require 'kconv'

class Entry
  def initialize(url)
    @url = url
    #@cache = Entry.get_cache_filename(url)
    @loaded = false
    @using_cache = false
  end

  attr_accessor :url, :cache, :title, :time, :bid, :bookmarks, :loaded, :using_cache

  def load(time = nil)
    #load_cache
    @using_cache = true

    time = time || Time.local(2000, 1, 1)
    if @time.to_i == 0 || @time < time
      load_url
      @using_cache = false
    end

    @loaded = true
    self
  end

  def load_url
    rss = "http://b.hatena.ne.jp/entry/rss/" + @url.gsub("#", "%23").gsub(" ", "+")
    print "load #{@url}\n"
    begin
      open(rss) {|f|
        # http://blog.livedoor.jp/dankogai/archives/50410033.html
        str = f.read.scan(/([\x00-\x7f]|[\xC0-\xDF][\x80-\xBF]|[\xE0-\xEF][\x80-\xBF]{2}|[\xF0-\xF7][\x80-\xBF]{3})/).join
        
        doc = REXML::Document.new(str)
        title = REXML::XPath.first(doc, "//channel/title")
        link = REXML::XPath.first(doc, "//channel/link")
        if link == nil or link.text != @url or title == nil then
          @time = Time.now # hash bug? ex) http://b.hatena.ne.jp/tetsu23/%e5%9c%b0%e5%9b%b3/ 
          return
        end
        title = title.text.gsub(/[\n\t]/, '')
        
        bid = REXML::XPath.first(doc, "//rdf:li/@rdf:resource")
        bid = if bid && /#bookmark-(\d+)/ =~ bid.to_s then $1 else nil end
        raise 'bid changed' if !@bid.nil? && bid != @bid
        
        items = REXML::XPath.match(doc, "//item")
        items = items.map {|node|
          date = REXML::XPath.first(node, 'dc:date').text
          time = Time::local(*ParseDate.parsedate(date)[0 .. -3]) # assume +9:00
          
          id   = (REXML::XPath.first(node, 'title').text || "").to_s
          
          desc = (REXML::XPath.first(node, 'description').text || "").to_s
          
          tags = REXML::XPath.match(node, "dc:subject").map {|tag|
            tag.text.to_s
          }
          
          {:time => time,
            :id   => id,
            :tags => tags,
            :desc => desc}
        }
        
        @bid = bid
        @title = title if @title.nil?
        @time = Time.now

        @bookmarks = [] if @bookmarks.nil?
        @bookmarks = items + @bookmarks
        id_flag = {}
        @bookmarks = @bookmarks.reverse.select {|item|
          if id_flag[item[:id]] then
            false
          else
            id_flag[item[:id]] = true
            true
          end
        }.reverse
      }
    rescue
      @bid = ''
      @title = ''
      @time = Time.now
      @bookmarks = []
    end

    #File.open(@cache, "w") {|f|
    #  f.puts self.dump
    #}
  end

  def load_cache
    return if !File.exist? @cache

    File.open(@cache) {|f|
      _header = {}
      _header[$1] = $2 while /([^:]+):(.*)/ =~ (f.gets || "").chomp
      @url   = _header['url']
      @title = _header['title']
      @bid   = _header['bid']
      @time  = Time.at((_header['time'] || "").to_i)

      @bookmarks = f.map {|line|
        time, id, desc = line.chomp.split(/\t/)
        next if id.nil?
        tags = []
        while (/^\[([^\]]+)\]/ =~ desc)
          tags.push $1
          desc = $'
        end
        desc = "" if desc.nil?

        {:time => Time.at(time.to_i),
          :id   => id,
          :tags => tags,
          :desc => desc}
      }.compact
    }
  end
  
  def dump
    str = "url:#{@url}\r\n" + 
      "title:#{@title}\r\n" + 
      "bid:#{@bid}\r\n" + 
      "time:#{@time.to_i.to_s}\r\n"

    bookmarks = []
    bookmarks = @bookmarks.map {|bookmark|
      bookmark[:time].to_i.to_s + "\t" +
      bookmark[:id] + "\t" + 
      (bookmark[:tags].size > 0 ? "[" + bookmark[:tags].join('][') + "]" : "") + 
      bookmark[:desc]
    } if @bookmarks
    
    str + "\r\n" + bookmarks.join("\r\n")
  end

  def self.get_cache_filename(url)
    base = "entry/" + Digest::MD5.hexdigest(url)
    Dir::glob(base + "*").each {|fn|
      return fn if self::get_cache_url(fn) == url
    }

    if !File.exist? base
      self::touch(base, url)
      return base
    end

    1.upto(100) {|i|
      fn = base + "-" + i.to_s
      if !File.exist? fn
        self::touch(fn, url)
        return fn
      end
    }
  end

  def self.get_cache_url(fn)
    File.open(fn) {|f|
      if (/^url:\s*(.*)/ =~ (f.gets || "").chomp)
        return $1
      end
    }
    nil
  end

  def self.touch(fn, url)
    File.open(fn, "w") {|f|
      f.puts "url:" + url
    }
  end
end
