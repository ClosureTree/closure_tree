module ClosureTree
  module Rebuild
    class Chains
      def initialize(table, hierarchies_table_name, options = {})
        @table = table
        @id = options.delete(:id) || :id
        @parent_id = options.delete(:parent_id) || :parent_id
      end

      def chains
        @chains ||= build_chains
      end

      private

      def tuples
        @tuples ||= @table.order(@parent_id).select_map([@id, @parent_id])
      end

      def build_chains
        [].tap do |c|
          tuples.each { |tuple| c.concat(chains_for(tuple[0])) }
        end
      end

      def chains_for(id)
        [].tap do |c|
          c << [id, id, 0]

          walk_up(id).each.with_index do |parent_id, index|
            c << [parent_id, id, index + 1]
          end
        end
      end

      def walk_up(id, cref = [])
        parent_id = tuples_hash[id]
        return [] unless parent_id

        if cref.include?(parent_id)
          raise "Cycle reference detected: #{id} <=> #{parent_id}"
        end

        [parent_id] + walk_up(parent_id, cref + [parent_id])
      end

      def tuples_hash
        @tuples_hash ||= index_tuples_by_id
      end

      def index_tuples_by_id
        {}.tap do |c|
          tuples.each do |(id, parent_id)|
            c[id] = parent_id
          end
        end
      end
    end
  end
end
