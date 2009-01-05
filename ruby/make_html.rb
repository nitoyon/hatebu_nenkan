require 'cgi'
require 'date'

date = Date.new(2005, 2)
thismonth = Date.today - Date.today.day + 1
thisyear = Date.new(thismonth.year, 1, 1)

count = 1
count += thismonth.year * 12 + thismonth.month - date.year * 12 - date.month + 1
count += thisyear.year - date.year + 1


def output_header()
	return <<EOS
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
	<title>はてブ年鑑</title>
	<link rel="stylesheet" type="text/css" href="nenkan.css">
	<script type="text/javascript">
	<!--
		var total_boxes = %%COUNT%%;
	//-->
	</script>
	<script type="text/javascript" src="init.js"></script>
</head>
<body>

<h1>はてブ年鑑</h1>
<div id="header"><a href="#yearly">年間ランキング</a> | <a href="#monthly">月間ランキング</a> | <a href="#about">このサイトについて</a> | <a href="http://d.hatena.ne.jp/nitoyon/">開発者ブログ</a></div>

<div id="main">
<div class="box" id="about">
	<div class="box_list">
		<h2>このサイトについて</h2>
		<div id="about_body">
			<h3>はてブ年鑑とは？</h3>
			<p>はてブ年鑑は <a href="http://b.hatena.ne.jp/">はてなブックマーク</a> の<strong>年間ランキング</strong>と<strong>月間ランキング</strong>を集計し、ランキングを生成するWebサービスです。</p>

			<h3>集計方法について</h3>
			<p>ブックマーク数は、年間・月間にブックマークしたパブリックユーザ数を元に算出しています。</p>
			<p>サイト別ランキングおよびタグ別ランキングは、期間中にホットエントリ入りしたエントリを対象に集計しています。</p>

			<h3>更新間隔について</h3>
			<p>現在、データ更新は手作業で行っています。月１～２回の更新を予定しています。</p>

			<h3>制限・注意事項</h3>
			<p>はてブ年鑑は、個人が運営するサイトであり、予告なくサービス内容の変更やサービスの停止を行うことがあります。ご了承ください。</p>

			<h3>連絡先</h3>
			<p>はてブ年鑑に関するお問い合わせは <img src="http://tech.nitoyon.com/img/icon/contact.png"> までお願いいたします。</p>
		</div>
	</div>
</div>

EOS
end

def output_summary(period, start, goal)
	date = start
	ret = "<a name=\"#{period}\"></a>"
	while(date <= goal)
		if(period == 'monthly') then
			fn = sprintf("summary/%04d%02d-", date.year, date.month)
			title = sprintf("%04d%02d", date.year, date.month)
		else
			fn = sprintf("summary/%04d-", date.year)
			title = date.year.to_s
		end

		ret += <<EOS
<div class="box #{period}" id="#{title}">
	<div class="box_list">
		<h2>#{title}</h2>

		<div class="entry">
			<ol class="entries">
EOS

		File.open(fn + "count.txt") do |f|
			1.upto(20) do |i|
				url, title, count = f.gets.chomp.split("\t")
				url = CGI.escapeHTML(url)
				title = CGI.escapeHTML(title)

				ret += <<EOS
				<li><a href="#{url}">#{title}</a><strong>#{count} users</strong></li>
EOS
			end
		end

		ret += <<EOS
			</ol>
		</div>

		<div class="domain">
			<h3>ドメイン別 ランキング</h3>
			<ol class="domain-rank">
EOS

		File.open(fn + "domain.txt") do |f|
			tags = {}
			1.upto(30) do |i|
				domain, count = f.gets.chomp.split("\t")

				ret += <<EOS
				<li>#{domain}<span>#{count}</span></li>
EOS
			end
		end

		ret += <<EOS
			</ol>
		</div>

		<div class="tag">
			<h3>タグ ランキング</h3>
			<ol class="tag-cloud">
EOS

		File.open(fn + "tag.txt") do |f|
			tags = {}
			1.upto(30) do |i|
				tag, count = f.gets.chomp.split("\t")
				tags[tag] = {'count' => count, 'rank' => i}
			end

			tags.keys.sort.each do |tag|
				ret += <<EOS
				<li class="tag#{tags[tag]['rank']}">#{tag}<span>#{tags[tag]['count']}</span>
EOS
			end
		end

		ret += <<EOS
			</ol>
		</div>
	</div>
</div>
EOS

		if period == 'monthly'
			date = date >> 1
		else
			date = Date.new(date.year + 1, 1, 1)
		end
	end
	return ret
end

def output_footer()
	return <<EOS
</div>

<div id="footer">Copyright &copy; はてブ年鑑. All rights reserved.</div>

<script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.2.6/jquery.min.js"></script>
<script type="text/javascript" src="swfobject.js"></script>
<script type="text/javascript" src="nenkan.js"></script>

</body>
</html>
EOS
end


$ret = output_header().sub("%%COUNT%%", count.to_s)
$ret += output_summary('yearly', date, thismonth)
$ret += output_summary('monthly', date, thismonth)
$ret += output_footer()

print $ret
