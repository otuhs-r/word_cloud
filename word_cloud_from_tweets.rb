require 'json'
require 'yaml'
require 'natto'
require 'magic_cloud'
require 'date'

def extract_tweets_from_json(file_path, from_date, to_date)
  open(file_path) { |io| JSON.load(io) }.map do |t|
    created_at = DateTime.parse(t["created_at"])
    if !t["retweeted"] && from_date <= created_at && created_at <= to_date
      t["full_text"].gsub("\n", '').gsub(/@.+\s/, "") unless t["retweeted"]
    end
  end.compact
end

def emoji_contained?(text)
  text&.each_char&.any? {|c| c.bytesize == 4 } || false
end

settings = open("settings.yml", 'r') { |f| YAML.load(f) }
input_path = settings["input_file_path"]
from_date, to_date = settings["term"].map { |dt| DateTime.parse(dt) }
tweets = extract_tweets_from_json(input_path, from_date, to_date)

# 1 Tweet ずつ形態素解析 → 名詞のワードカウント
words = {}
natto = Natto::MeCab.new
tweets.each do |tweet|
  natto.parse(tweet) do |n|
    words[n.surface] ? words[n.surface] += 1 : words[n.surface] = 1 if n.feature.match("名詞")
  end
end

# 出現回数上位 100 個を抽出

stop_words = []
File.open(settings["stop_words_file_path"], mode = "rt") { |f| stop_words = f.readlines.map{ |w| w.chomp } }
top_words = words.to_a.reject { |(w, c)| w.match?(/^[a-zA-Z\d]+|^ｗ+$/) || stop_words.include?(w) || emoji_contained?(w) }.sort { |(_k1, v1), (_k2, v2)| v2 <=> v1 }[0..100]
p top_words

# ワードクラウド作成
cloud = MagicCloud::Cloud.new(top_words, rotate: :none, scale: :log, font_family: 'Arial Unicode')
img = cloud.draw(960, 600) #default height/width
img.write("output/#{from_date.strftime("%Y%m%d")}-#{to_date.strftime("%Y%m%d")}.png")
