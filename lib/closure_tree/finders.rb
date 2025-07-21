# frozen_string_literal: true

module ClosureTree
  module Finders
    extend ActiveSupport::Concern

    # Find a descendant node whose +ancestry_path+ will be ```self.ancestry_path + path```
    def find_by_path(path, attributes = {})
      return self if path.empty?

      self.class.find_by_path(path, attributes, id)
    end

    # Find or create a descendant node whose +ancestry_path+ will be ```self.ancestry_path + path```
    def find_or_create_by_path(path, attributes = {})
      subpath = _ct.build_ancestry_attr_path(path, attributes)
      return self if subpath.empty?

      found = find_by_path(subpath, attributes)
      return found if found

      attrs = subpath.shift
      _ct.with_advisory_lock do
        # shenanigans because children.create is bound to the superclass
        # (in the case of polymorphism):
        child = children.where(attrs).first || begin
          # Support STI creation by using base_class:
          _ct.create(self.class, attrs).tap do |ea|
            # We know that there isn't a cycle, because we just created it, and
            # cycle detection is expensive when the node is deep.
            ea._ct_skip_cycle_detection!
            children << ea
          end
        end
        child.find_or_create_by_path(subpath, attributes)
      end
    end

    def find_all_by_generation(generation_level)
      hierarchy_table = self.class.hierarchy_class.arel_table
      model_table = self.class.arel_table

      # Build the subquery
      descendants_subquery = hierarchy_table
                             .project(hierarchy_table[:descendant_id])
                             .where(hierarchy_table[:ancestor_id].eq(id))
                             .group(hierarchy_table[:descendant_id])
                             .having(hierarchy_table[:generations].maximum.eq(generation_level.to_i))
                             .as('descendants')

      # Build the join
      join_source = model_table
                    .join(descendants_subquery)
                    .on(model_table[_ct.base_class.primary_key].eq(descendants_subquery[:descendant_id]))
                    .join_sources

      s = _ct.base_class.joins(join_source)
      _ct.scope_with_order(s)
    end

    def without_self(scope)
      scope.without_instance(self)
    end

    class_methods do
      def without_instance(instance)
        if instance.new_record?
          all
        else
          where(["#{_ct.quoted_table_name}.#{_ct.quoted_id_column_name} != ?", instance.id])
        end
      end

      def roots
        _ct.scope_with_order(where(_ct.parent_column_name => nil))
      end

      # Returns an arbitrary node that has no parents.
      def root
        roots.first
      end

      def leaves
        hierarchy_table = hierarchy_class.arel_table
        model_table = arel_table

        # Build the subquery for leaves (nodes with no children)
        leaves_subquery = hierarchy_table
                          .project(hierarchy_table[:ancestor_id])
                          .group(hierarchy_table[:ancestor_id])
                          .having(hierarchy_table[:generations].maximum.eq(0))
                          .as('leaves')

        # Build the join
        join_source = model_table
                      .join(leaves_subquery)
                      .on(model_table[primary_key].eq(leaves_subquery[:ancestor_id]))
                      .join_sources

        s = joins(join_source)
        _ct.scope_with_order(s.readonly(false))
      end

      def with_ancestor(*ancestors)
        ancestor_ids = ancestors.map { |ea| ea.is_a?(ActiveRecord::Base) ? ea._ct_id : ea }
        scope = if ancestor_ids.blank?
                  all
                else
                  joins(:ancestor_hierarchies)
                    .where("#{_ct.hierarchy_table_name}.ancestor_id" => ancestor_ids)
                    .where("#{_ct.hierarchy_table_name}.generations > 0")
                    .readonly(false)
                end
        _ct.scope_with_order(scope)
      end

      def with_descendant(*descendants)
        descendant_ids = descendants.map { |ea| ea.is_a?(ActiveRecord::Base) ? ea._ct_id : ea }
        scope = if descendant_ids.blank?
                  all
                else
                  joins(:descendant_hierarchies)
                    .where("#{_ct.hierarchy_table_name}.descendant_id" => descendant_ids)
                    .where("#{_ct.hierarchy_table_name}.generations > 0")
                    .readonly(false)
                end
        _ct.scope_with_order(scope)
      end

      def lowest_common_ancestor(*descendants)
        descendants = descendants.first if descendants.length == 1 && descendants.first.respond_to?(:each)
        ancestor_id = hierarchy_class
                      .where(descendant_id: descendants)
                      .group(:ancestor_id)
                      .having("COUNT(ancestor_id) = #{descendants.count}")
                      .order(Arel.sql('MIN(generations) ASC'))
                      .limit(1)
                      .pluck(:ancestor_id).first

        find_by(primary_key => ancestor_id) if ancestor_id
      end

      def find_all_by_generation(generation_level)
        hierarchy_table = hierarchy_class.arel_table
        model_table = arel_table

        # Build the roots subquery
        roots_subquery = model_table
                         .project(model_table[primary_key].as('root_id'))
                         .where(model_table[_ct.parent_column_sym].eq(nil))
                         .as('roots')

        # Build the descendants subquery
        descendants_subquery = hierarchy_table
                               .project(
                                 hierarchy_table[:ancestor_id],
                                 hierarchy_table[:descendant_id]
                               )
                               .group(hierarchy_table[:ancestor_id], hierarchy_table[:descendant_id])
                               .having(hierarchy_table[:generations].maximum.eq(generation_level.to_i))
                               .as('descendants')

        # Build the joins
        # Note: We intentionally use a cartesian product join (CROSS JOIN) here.
        # This allows us to find all nodes at a specific generation level across all root nodes.
        # The 1=1 condition creates this cartesian product in a database-agnostic way.
        join_roots = model_table
                     .join(roots_subquery)
                     .on(Arel.sql('1 = 1'))

        join_descendants = join_roots
                           .join(descendants_subquery)
                           .on(
                             model_table[primary_key].eq(descendants_subquery[:descendant_id])
                             .and(roots_subquery[:root_id].eq(descendants_subquery[:ancestor_id]))
                           )

        s = joins(join_descendants.join_sources)
        _ct.scope_with_order(s)
      end

      # Find the node whose +ancestry_path+ is +path+
      def find_by_path(path, attributes = {}, parent_id = nil)
        return nil if path.blank?

        path = _ct.build_ancestry_attr_path(path, attributes)
        return _ct.find_by_large_path(path, attributes, parent_id) if path.size > _ct.max_join_tables

        scope = where(path.pop)
        last_joined_table = _ct.table_name

        path.reverse.each_with_index do |ea, idx|
          next_joined_table = "p#{idx}"
          scope = scope.joins(<<-SQL.squish)
            INNER JOIN #{_ct.quoted_table_name} #{_ct.t_alias_keyword} #{next_joined_table}
              ON #{next_joined_table}.#{_ct.quoted_id_column_name} =
 #{connection.quote_table_name(last_joined_table)}.#{_ct.quoted_parent_column_name}
          SQL
          scope = _ct.scoped_attributes(scope, ea, next_joined_table)
          last_joined_table = next_joined_table
        end

        scope.where("#{last_joined_table}.#{_ct.parent_column_name}" => parent_id).readonly(false).first
      end

      # Find or create nodes such that the +ancestry_path+ is +path+
      def find_or_create_by_path(path, attributes = {})
        attr_path = _ct.build_ancestry_attr_path(path, attributes)
        find_by_path(attr_path) || begin
          root_attrs = attr_path.shift
          _ct.with_advisory_lock do
            # shenanigans because find_or_create can't infer that we want the same class as this:
            # Note that roots will already be constrained to this subclass (in the case of polymorphism):
            root = roots.where(root_attrs).first || _ct.create!(self, root_attrs)
            root.find_or_create_by_path(attr_path)
          end
        end
      end
    end
  end
end
