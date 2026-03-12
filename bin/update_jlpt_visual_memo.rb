#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"
require "yaml"

DECK_DIR = Pathname("JLPT/n2_frequent_vocabulary_001")
DICT_PATH = Pathname(ENV.fetch("MAKEMEHANZI_DICTIONARY", "/tmp/makemeahanzi-dictionary.txt"))
IDS_PATH = Pathname(ENV.fetch("CJKVI_IDS", "/tmp/cjkvi-ids.txt"))

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
  "働" => {
    radical: "亻",
    type_label: "회의겸형성자",
    decomposition: "亻+動"
  },
  "咲" => {
    radical: "口",
    type_label: "국자",
    decomposition: "口+关"
  },
  "喫" => {
    radical: "口",
    type_label: "회의겸형성자",
    decomposition: "口+契"
  },
  "菓" => {
    radical: "艸",
    type_label: "형성자",
    semantic: "艸",
    phonetic: "果"
  },
  "扱" => {
    radical: "扌",
    qualifier: "일본 상용 약자",
    decomposition: "扌+及"
  },
  "査" => {
    type_label: "표의계 글자",
    decomposition: "木+旦"
  }
}.freeze

IDS_OPERATORS = /[⿰⿱⿲⿳⿴⿵⿶⿷⿸⿹⿺⿻]/.freeze
ANNOTATION = /\[[^\]]+\]/.freeze
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

def resolved_character(character)
  VARIANT_MAP.fetch(character, character)
end

def type_label_for(type)
  case type
  when "pictographic"
    "상형자"
  when "ideographic"
    "표의계 글자"
  when "pictophonetic"
    "형성자"
  end
end

def clean_decomposition(value)
  return nil if value.nil? || value.empty?

  cleaned = value.gsub(ANNOTATION, "").gsub(IDS_OPERATORS, "")
  pieces = cleaned.each_char.reject { |piece| piece.empty? || piece == "？" }
  return nil if pieces.empty?

  pieces.join("+")
end

def char_info(character, dictionary, ids)
  override = MANUAL_OVERRIDES[character] || {}
  resolved = override.fetch(:source, resolved_character(character))
  entry = dictionary[resolved] || {}

  decomposition =
    override[:decomposition] ||
    clean_decomposition(entry["decomposition"]) ||
    clean_decomposition(ids[character]) ||
    clean_decomposition(ids[resolved])

  {
    original: character,
    resolved: resolved,
    radical: override[:radical] || entry["radical"],
    type_label: override[:type_label] || type_label_for(entry.dig("etymology", "type")),
    semantic: override[:semantic] || entry.dig("etymology", "semantic"),
    phonetic: override[:phonetic] || entry.dig("etymology", "phonetic"),
    decomposition: decomposition,
    qualifier: override[:qualifier]
  }
end

def component_detail(info)
  if info[:decomposition] &&
      (info[:qualifier] || info[:type_label].nil? || ["국자", "회의겸형성자"].include?(info[:type_label]))
    "(자형 #{info[:decomposition]})"
  end
end

def char_fragment(info)
  phrases = []
  phrases << "#{info[:original]}:"
  phrases << "신자체라 구자체 #{info[:resolved]} 기준," if info[:resolved] != info[:original]
  phrases << "#{info[:qualifier]}," if info[:qualifier]
  phrases << "#{info[:radical]} 부수" if info[:radical]
  phrases << info[:type_label] if info[:type_label]

  detail = component_detail(info)
  fragment = phrases.join(" ")
  detail ? "#{fragment}#{detail}" : fragment
end

def visual_line_for(note, dictionary, ids)
  characters = note.fetch("target").scan(/\p{Han}/).reject { |character| character == "々" }
  snippets = characters.first(2).map { |character| char_fragment(char_info(character, dictionary, ids)) }
  lead =
    if snippets.length == 1
      "#{snippets.first}로 본다."
    else
      "#{snippets.join(', ')}로 쪼개 본다."
    end

  "[1차원/시각] #{lead} 부수와 제자 원리를 먼저 붙이면 '#{note.fetch('meaning')}' 뜻이 글자 모양째 고정된다."
end

def note_lines_by_target(path, dictionary, ids)
  notes = YAML.load_file(path).fetch("notes")
  notes.to_h do |note|
    [note.fetch("target"), visual_line_for(note, dictionary, ids)]
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
yaml_files = Dir[DECK_DIR.join("*.yaml")].reject { |path| path.end_with?("build.yaml") }.sort

yaml_files.each do |file|
  path = Pathname(file)
  replacements = note_lines_by_target(path, dictionary, ids)
  rewrite_file(path, replacements)
end

puts "Updated visual memo lines in #{yaml_files.size} files."
