#!/usr/bin/env ruby

require 'bundler/setup'
require 'cycr'
require 'progress'
require 'slop'
require 'csv'
require 'wordnet'
require 'wiktionary/noun'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -i input.csv -m mapping.csv -o output.csv\n" +
    "Find parents for missing WordNet synsets withing Cyc"

  on :i=, :input, "File with WordNet synsets that are missing in Cyc", required: true
  on :m=, :mapping, "Input file with Cyc - WordNet mapping", required: true
  on :o=, :output, "Output file with the new mapping", required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

nouns = Wiktionary::Noun.new
wordnet = WordNet::Lemma

mapping = {}
cyc_mapping = {}
CSV.open(options[:mapping]) do |input|
  input.with_progress do |lemma,_,wordnet_id,_,cyc_id,cyc_name|
    mapping[wordnet_id.to_i] = cyc_id
    cyc_mapping[cyc_id] = cyc_name
  end
end

def find_parent(synset,mapping)
  return mapping[synset.pos_offset] if mapping[synset.pos_offset]
  return find_parent(synset.hypernym,mapping) if synset.hypernym
  return nil
end

index = 0
lemmas = nil
CSV.open(options[:input]) do |input|
  CSV.open(options[:output],"w") do |output|
    input.with_progress do |concept|
      begin
        concepts = concept.first.split(" ")
        parents = []
        (nouns.singularize(concepts[-1]) + [concepts[-1]]).each do |last_concept|
          concepts[-1] = last_concept
          lemmas = concepts.map{|e| e.downcase.sub(/ /,"-") }
          lemma = wordnet.find(lemmas.join("_"),:noun)
          lemma = wordnet.find(lemmas.join("-"),:noun) if lemma.nil?
          next unless lemma
          lemma.synsets.each do |synset|
            cyc_parent_id = find_parent(synset,mapping)
            parents << cyc_parent_id if cyc_parent_id
          end
        end
        parents.uniq!
        output << [concept.first,*parents.map{|id| [id,cyc_mapping[id]] }.flatten(1)] unless parents.empty?
      rescue => ex
        puts ex
        puts concept
        p lemmas
      end
    end
  end
end
