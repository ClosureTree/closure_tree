#!/usr/bin/env ruby

# Benchmark for loading a tree, based on the topology of the current filesystem.

require 'spec_helper'
require 'findler'
require 'pathname'

# Returns the current path, split into an array.
# Pathname.new("/a/b/c").path_array = ["a", "b", "c"]
class Pathname
  def path_array
    a = []
    each_filename { |ea| a << ea }
    a
  end
end

f = Findler.new '/'
iter = f.iterator
Tag.with_advisory_lock('closure_tree') do
  while (nxt = iter.next_file)
    Tag.find_or_create_by_path(nxt.path_array)
  end
end

puts "Tag.all.size: #{Tag.all.size}"
puts "TagHierarchy.all.size: #{TagHierarchy.all.size}"

puts 'Tag.roots performance:'
puts Benchmark.measure { Tag.roots.size }

puts 'Tag.leaves performance:'
puts Benchmark.measure { Tag.leaves.size }

