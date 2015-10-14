#!/usr/bin/env ruby

require 'bundler/setup'
require 'cycr'
require 'progress'
require 'slop'
require 'csv'
require 'wordnet'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -i input.csv -m mapping.csv -o output.csv\n" +
    "Convert Cyc-WordNet mapping to include ids from WordNet 3.0"

  on :i=, :input, "Input file with Cyc - WordNet mapping", required: true
  on :m=, :mapping, "WordNet 2.0 to WordNet 3.0 mapping", required: true
  on :o=, :output, "Output file with the new mapping", required: true
  on :w=, :wordnet, "The path to WordNet 2.0", required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
end

mapping = {}
CSV.open(options[:mapping]) do |input|
  input.with_progress do |wordnet_3,wordnet_2|
    mapping[wordnet_2.to_i] = wordnet_3.to_i
  end
end

WordNet::DB.path = options[:wordnet]
wordnet = WordNet::Lemma#.find("plant", :noun).synsets

CSV.open(options[:input]) do |input|
  CSV.open(options[:output],"w") do |output|
    output << ["#lemma","wordnet_2.0","wordnet_3.0","POS","Cyc ID","Cyc name"]
    input.with_progress do |wordnet_2_name,cyc_id,cyc_name|
      begin
        elements = wordnet_2_name.split("-")
        index = elements.pop.to_i
        pos = elements.pop
        case pos
        when /^noun/
          prefix = "1"
        when /^verb/
          prefix = "2"
        when /^adj/
          prefix = "3"
          pos = "adj"
        when /^adv/
          prefix = "4"
          pos = "adv"
        else
          next
        end
        elements.shift
        lemma = elements.join("-")
        synset = wordnet.find(lemma.downcase,pos.to_sym).synsets[index-1]
        pos_offset = ("#{prefix}%08i" % synset.pos_offset).to_i
        output << [lemma,pos_offset,mapping[pos_offset],pos,cyc_id,cyc_name]
      rescue => ex
        puts ex
        puts "Error for: #{wordnet_2_name} #{elements.join("_")} #{pos}"
      end
    end
  end
end
