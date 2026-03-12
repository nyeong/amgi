#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "pathname"
require "uri"
require "yaml"

DECK_DIR = Pathname("JLPT/n2_frequent_vocabulary_001")
DICT_PATH = Pathname(ENV.fetch("MAKEMEHANZI_DICTIONARY", "/tmp/makemeahanzi-dictionary.txt"))
IDS_PATH = Pathname(ENV.fetch("CJKVI_IDS", "/tmp/cjkvi-ids.txt"))
KANJIPEDIA_CACHE_PATH = Pathname(ENV.fetch("KANJIPEDIA_CACHE", "/tmp/kanjipedia_cache.json"))

VARIANT_MAP = {
  "両" => "兩",
  "仮" => "假",
  "伝" => "傳",
  "価" => "價",
  "児" => "兒",
  "剣" => "劍",
  "勧" => "勸",
  "単" => "單",
  "厳" => "嚴",
  "収" => "收",
  "団" => "團",
  "囲" => "圍",
  "売" => "賣",
  "変" => "變",
  "実" => "實",
  "対" => "對",
  "巻" => "卷",
  "広" => "廣",
  "応" => "應",
  "恵" => "惠",
  "悩" => "惱",
  "戦" => "戰",
  "戻" => "戾",
  "抜" => "拔",
  "拡" => "擴",
  "査" => "查",
  "検" => "檢",
  "楽" => "樂",
  "歩" => "步",
  "歳" => "歲",
  "歴" => "歷",
  "気" => "氣",
  "氷" => "冰",
  "汚" => "污",
  "涙" => "淚",
  "済" => "濟",
  "焼" => "燒",
  "畳" => "疊",
  "窓" => "窗",
  "経" => "經",
  "絵" => "繪",
  "絶" => "絕",
  "続" => "續",
  "薬" => "藥",
  "覚" => "覺",
  "観" => "觀",
  "転" => "轉",
  "辺" => "邊",
  "遅" => "遲",
  "郷" => "鄉",
  "鋭" => "銳",
  "険" => "險",
  "隣" => "鄰",
  "雑" => "雜",
  "頼" => "賴",
  "騒" => "騷",
  "齢" => "齡",
  "増" => "增",
  "姉" => "姊"
}.freeze

MANUAL_OVERRIDES = {
  "働" => { radical: "亻" },
  "咲" => { radical: "口" },
  "喫" => { radical: "口" },
  "菓" => { radical: "艸" },
  "扱" => { radical: "扌" }
}.freeze

TYPE_LABELS = {
  "形声" => "형성자",
  "会意" => "회의자",
  "象形" => "상형자",
  "指事" => "지사자",
  "会意兼形声" => "회의겸형성자",
  "会意形声" => "회의겸형성자",
  "形声兼会意" => "형성겸회의자",
  "象形兼会意" => "상형겸회의자",
  "会意兼指事" => "회의겸지사자"
}.freeze

TARGET_LINE = /^  - target: "(.*)"$/.freeze
MEMO_START_LINE = /^    memo: \|$/.freeze
VISUAL_LINE = /^      \[1차원\/시각\]/.freeze

def load_dictionary(path)
  raise "makemeahanzi dictionary not found: #{path}" unless path.exist?

  {}.tap do |dictionary|
    path.each_line do |line|
      entry = JSON.parse(line)
      dictionary[entry.fetch("character")] = entry
    end
  end
end

def load_ids(path)
  raise "cjkvi ids file not found: #{path}" unless path.exist?

  {}.tap do |ids|
    path.each_line do |line|
      next if line.start_with?("#") || line.strip.empty?

      columns = line.split("\t")
      character = columns[1]
      decomposition = columns[2]
      next unless character && decomposition

      ids[character] = decomposition.strip
    end
  end
end

def load_cache(path)
  return {} unless path.exist?

  JSON.parse(path.read)
end

def save_cache(path, cache)
  path.write(JSON.pretty_generate(cache))
end

def fetch_html(url)
  uri = URI(url)

  3.times do |index|
    response = Net::HTTP.get_response(uri)
    if response.is_a?(Net::HTTPSuccess)
      return response.body.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace)
    end

    sleep(0.5 * (index + 1))
  end

  raise "failed to fetch #{url}"
end

def normalize_text(html)
  html
    .gsub(/<br\s*\/?>/i, " ")
    .gsub(/<[^>]+>/, " ")
    .gsub(/&nbsp;/, " ")
    .gsub(/\s+/, " ")
    .strip
end

def fetch_kanjipedia_entry(character, cache)
  if cache.key?(character)
    cached = cache[character]
    if cached && cached["naritachi"]
      cached["type_raw"] = cached["naritachi"][/会意兼形声|形声兼会意|会意形声|象形兼会意|会意兼指事|形声|会意|象形|指事/, 0]
    end
    return cached
  end

  query = URI.encode_www_form_component(character)
  search_html = fetch_html("https://www.kanjipedia.jp/search?k=#{query}&kt=1&sk=perfect")
  page_path = search_html[/<a href="(\/kanji\/\d+)">#{Regexp.escape(character)}<\/a>/, 1]

  if page_path.nil?
    cache[character] = nil
    return nil
  end

  article_html = fetch_html("https://www.kanjipedia.jp#{page_path}")
  naritachi_html = article_html[%r{<li class="naritachi">.*?<div>\s*<p>\s*(.*?)\s*</p>\s*</div>}m, 1]
  naritachi = normalize_text(naritachi_html.to_s)
  type_raw = naritachi[/会意兼形声|形声兼会意|会意形声|象形兼会意|会意兼指事|形声|会意|象形|指事/, 0]

  cache[character] = {
    "page_path" => page_path,
    "naritachi" => naritachi,
    "type_raw" => type_raw
  }
end

def resolved_character(character)
  VARIANT_MAP.fetch(character, character)
end

def radical_for(character, dictionary, ids)
  override = MANUAL_OVERRIDES[character]
  return override[:radical] if override&.dig(:radical)

  resolved = resolved_character(character)
  dictionary.dig(character, "radical") ||
    dictionary.dig(resolved, "radical")
end

def type_label_for(type_raw)
  return nil if type_raw.nil? || type_raw.empty?

  TYPE_LABELS.fetch(type_raw, "#{type_raw} 계열")
end

def fallback_type_label(character, dictionary)
  resolved = resolved_character(character)
  entry = dictionary[character] || dictionary[resolved] || {}

  case entry.dig("etymology", "type")
  when "pictographic"
    "상형자"
  when "ideographic"
    "표의계 글자"
  when "pictophonetic"
    "형성자"
  end
end

def char_info(character, dictionary, ids, cache)
  entry = fetch_kanjipedia_entry(character, cache)
  type_raw = entry&.fetch("type_raw", nil)
  type_label = type_label_for(type_raw) || fallback_type_label(character, dictionary)

  {
    original: character,
    radical: radical_for(character, dictionary, ids),
    type_raw: type_raw,
    type_label: type_label
  }
end

def char_fragment(info)
  fragment = +"#{info[:original]}:"
  fragment << " #{info[:radical]} 부수" if info[:radical]

  if info[:type_label] && info[:type_raw]
    fragment << ", #{info[:type_label]}(#{info[:type_raw]})"
  elsif info[:type_label]
    fragment << ", #{info[:type_label]}"
  end

  fragment
end

def visual_line_for(note, dictionary, ids, cache)
  characters = note.fetch("target").scan(/\p{Han}/).reject { |character| character == "々" }
  snippets = characters.map { |character| char_fragment(char_info(character, dictionary, ids, cache)) }

  "[1차원/시각] #{snippets.join('. ')}. 먼저 각 글자의 부수와 성립부터 붙여 본다."
end

def note_lines_by_target(path, dictionary, ids, cache)
  notes = YAML.load_file(path).fetch("notes")
  notes.to_h do |note|
    [note.fetch("target"), visual_line_for(note, dictionary, ids, cache)]
  end
end

def rewrite_file(path, replacements)
  current_target = nil
  waiting_for_visual_line = false

  updated_lines = path.each_line.map do |line|
    if (match = line.match(TARGET_LINE))
      current_target = match[1]
      waiting_for_visual_line = false
      line
    elsif line.match?(MEMO_START_LINE)
      waiting_for_visual_line = true
      line
    elsif waiting_for_visual_line && line.match?(VISUAL_LINE)
      waiting_for_visual_line = false
      "      #{replacements.fetch(current_target)}\n"
    else
      line
    end
  end

  path.write(updated_lines.join)
end

dictionary = load_dictionary(DICT_PATH)
ids = load_ids(IDS_PATH)
cache = load_cache(KANJIPEDIA_CACHE_PATH)
yaml_files = Dir[DECK_DIR.join("*.yaml")].reject { |path| path.end_with?('amgi.yaml') }.sort
unique_characters = yaml_files.flat_map do |file|
  YAML.load_file(file).fetch("notes").flat_map { |note| note.fetch("target").scan(/\p{Han}/) }
end.uniq.reject { |character| character == "々" }

unique_characters.each_with_index do |character, index|
  fetch_kanjipedia_entry(character, cache)
  warn "[#{index + 1}/#{unique_characters.length}] #{character}" if ((index + 1) % 50).zero?
end

save_cache(KANJIPEDIA_CACHE_PATH, cache)

yaml_files.each do |file|
  path = Pathname(file)
  replacements = note_lines_by_target(path, dictionary, ids, cache)
  rewrite_file(path, replacements)
end

puts "Updated visual memo lines in #{yaml_files.size} files."
