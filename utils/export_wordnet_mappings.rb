#!/usr/bin/env ruby

require 'bundler/setup'
require 'cycr'
require 'progress'
require 'slop'
require 'csv'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -o output.csv [-p port] [-h host]\n" +
    "Export WordNet - Cyc mapping from the ontology into CSV file"

  on :o=, :output, "Output file with the mapping"
  on :p=, :port, "Cyc port", default: 3601, as: Integer
  on :h=, :host, "Cyc host", default: "localhost"
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end


cyc = Cyc::Client.new(port: options[:port], host: options[:host])
service = Cyc::Service::NameService.new(cyc)
assertions = cyc.gather_mt_index([:ContextOfPCWFn, [:OWLOntologyFn, "http://www.w3.org/2006/03/wn/wn20/instances"]])
CSV.open(options[:output],"w") do |output|
  assertions.each do |assertion|
    begin
      term = service.find_by_term_name(assertion.formula[1].to_s)
      output << [assertion.formula[-1],term.id,term.name]
    rescue Exception => ex
      puts ex
      puts assertion.formula
    end
  end
end
