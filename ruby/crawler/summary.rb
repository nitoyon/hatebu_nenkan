require 'daily_rank'
require 'entry'
require 'lax_uri'


#------------------

class Summary
  def initialize(period, date)
    @period = period
    @date = self.normalize(date)
    @range = self.range(@date)
    @count = 50
  end

  def in_range?(date)
    @period == 'monthly' && @date.year == date.year && @date.month == date.month ||
      @period == 'yearly' && @date.year == date.year
  end

  def normalize(date)
    if @period == 'monthly' then
      return Date.new(date.year, date.month, 1)
    end
    if @period == 'yearly' then
      return Date.new(date.year, 1, 1)
    end
  end
  
  def range(d)
    ret = []

    while(in_range?(d))
      ret.push d
      d += 1
    end
    return ret
  end

  def get_domain(url)
    return url.sub(%r|https?://([^/]+).*|, '\1')
  end

  def exec2
    urls = @range.map { |date|
      if date >= Date.today
        nil
      else
        rank = DailyRank.new(date.year, date.month, date.day).load
        rank.entries[0 .. @count - 1].map do |entry| entry[:url] end
      end
    }.flatten.compact.uniq

    tags = {}
    domains = {}
    count = {}
    urls.each do |url|
      entry = Entry.new(url).load

      entry.bookmarks = entry.bookmarks.select do |bookmark|
        if self.in_range? bookmark[:time] then
          bookmark[:tags].each {|tag|
            tags[tag.downcase] = (tags[tag.downcase] || 0) + 1
          }
          true
        end
      end
      count[url] = [entry.bookmarks.length, entry.title]
      domain = get_domain(url)
      domains[domain] = (domains[domain] || 0) + entry.bookmarks.length
    end

    # sort
    urls.sort! do |a, b|
      count[b][0] <=> count[a][0]
    end

    tag_keys = tags.keys.sort do |a, b|
      tags[b] <=> tags[a]
    end

    domain_keys = domains.keys.sort do |a, b|
      domains[b] <=> domains[a]
    end

    # return
    return {
      :count =>
      urls[0..29].map do |url|
        {:url => url,
          :count => count[url][0],
          :title => count[url][1]}
      end,
      :tag =>
      tag_keys[0 .. 49].map do |tag|
        {:name => tag,
          :count => tags[tag]}
      end,
      :domain =>
      domain_keys[0 .. 49].map do |domain|
        {:name => domain,
          :count => domains[domain]}
      end,
    }
  end

  def getFilename
    if @period == 'monthly'
      sprintf("summary/%04d%02d", @date.year, @date.month)
    elsif @period == 'yearly'
      sprintf("summary/%04d", @date.year)
    end
  end

  def dump_domain(result)
    open(getFilename + "domain.txt", "w") do |f|
      result[:domain].each do |domain|
        f.puts sprintf("%s\t%s\n", domain[:name], domain[:count])
      end
    end
  end

  def dump(result)
    open(getFilename + "count.txt", "w") do |f|
      result[:count].each do |entry|
        f.puts sprintf("%s\t%s\t%s\n", entry[:url], entry[:title], entry[:count])
      end
    end

    open(getFilename + "tag.txt", "w") do |f|
      result[:tag].each do |tag|
        f.puts sprintf("%s\t%s\n", tag[:name], tag[:count])
      end
    end
  end
end
