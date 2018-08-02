require 'mechanize'
require 'pry'
require 'CSV'

def convert_number(str)
  [['①','1 '],['②','2 '],['③','3 '],['④','4 '],['⑤','5 '],['⑥','6 ']].each do |rule|
    str = str.to_s.gsub(rule[0], rule[1])
  end
  str
end

def sjis_safe(str)
  [
    ["301C", "FF5E"], # wave-dash
    ["2212", "FF0D"], # full-width minus
    ["00A2", "FFE0"], # cent as currency
    ["00A3", "FFE1"], # lb(pound) as currency
    ["00AC", "FFE2"], # not in boolean algebra
    ["2014", "2015"], # hyphen
    ["2016", "2225"], # double vertical lines
    ['00F6', '006F'],
    ['2B50', '']
  ].inject(str) do |s, (before, after)|
    s.gsub(
      before.to_i(16).chr('UTF-8'),
      after.to_i(16).chr('UTF-8'))
  end
end

def safe_str(str)
  begin
    new_str = sjis_safe(convert_number(str)).encode(Encoding::SJIS)
  rescue => exception
    p exception    
    ""
  end
end

def scrape_milltalk(query)
  email = 'oguma@shales.jp'
  password = 'shales0524'
  agent = Mechanize.new
  agent.user_agent = 'Mac Safari'
  agent.get('https://milltalk.jp/sessions/new/company') do |page|
    response = page.form_with(:action => '/sessions/new/company') do |form|
      formdata = {
        :mail => email,
        :password => password,
      }
      form.field_with(:name => 'email').value = formdata[:mail]
      form.field_with(:name => 'password').value = formdata[:password]
    end.submit
  end

  url = "https://milltalk.jp/?utf8=%E2%9C%93&conditions%5Bsort%5D=3&conditions%5Bsort%5D=3&conditions%5Bkeyword%5D=#{query}"
  page = agent.get(url)
  items = page.search('div.box-board-part')
  urls = items.map do |item|
    url = "https://milltalk.jp" + item.at('a').attributes['href'].value
  end

  results = urls.map do |page_url|
    item_agent = Mechanize.new
    item_page = agent.get(page_url)
    title = item_page.at('h1').text
    category = item_page.at('.board-owner').text
    sub = item_page.at('.board-about').text.gsub("\n",'').gsub(' ','')
    comments = item_page.search('div.board-entry')
    comment_results = comments.map do |comment|
      body = comment.at('p.comment').text.gsub("\n",'').gsub(' ','')
      author = comment.at('p.name').text.gsub(' ','').gsub(/^\n/,'').gsub(/\n$/,'').split("\n")
      {body: body, author: author}
    end
    {url: page_url, title: title, comment_results: comment_results, sub: sub, category: category}
  end

  CSV.open("comments_#{query}.csv",'w', encoding: "CP932:UTF-8") do |csv|
    csv << ['クエリー', 'URL', 'カテゴリー', 'タイトル', 'サブタイトル', '名前', '年齢', '性別', 'コメント']
    results.each do |result|
      result[:comment_results].each do |com|
        body_text = com[:body]
        data = [query, result[:url], result[:category], result[:title], result[:sub], com[:author][0], com[:author][1], com[:author][2], body_text]
        next if data[6] == "" || data[7] == "" || data[6] == nil || data[7] == nil
        safe_data = data.map{|row|
          safe_str(row.to_s)
        }        
        csv << safe_data
      end    
    end
  end
end

puts('input words...')
word = gets.chomp
puts('ok! scraping...')
scrape_milltalk(word)