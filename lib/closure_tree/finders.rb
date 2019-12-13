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
        child = self.children.where(attrs).first || begin
          # Support STI creation by using base_class:
          _ct.create(self.class, attrs).tap do |ea|
            # We know that there isn't a cycle, because we just created it, and
            # cycle detection is expensive when the node is deep.
            ea._ct_skip_cycle_detection!
            self.children << ea
          end
        end
        child.find_or_create_by_path(subpath, attributes)
      end
    end

    def find_all_by_generation(generation_level)
      s = _ct.base_class.joins(<<-SQL.squish)
        INNER JOIN (
          SELECT descendant_id
          FROM #{_ct.quoted_hierarchy_table_name}
          WHERE ancestor_id = #{_ct.quote(self.id)}
          GROUP BY descendant_id
          HAVING MAX(#{_ct.quoted_hierarchy_table_name}.generations) = #{generation_level.to_i}
        ) #{ _ct.t_alias_keyword } descendants ON (#{_ct.quoted_table_name}.#{_ct.base_class.primary_key} = descendants.descendant_id)
      SQL
      _ct.scope_with_order(s)
    end

    def without_self(scope)
      scope.without_instance(self)
    end

    module ClassMethods

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
        s = joins(<<-SQL.squish)
          INNER JOIN (
            SELECT ancestor_id
            FROM #{_ct.quoted_hierarchy_table_name}
            GROUP BY ancestor_id
            HAVING MAX(#{_ct.quoted_hierarchy_table_name}.generations) = 0
          ) #{ _ct.t_alias_keyword } leaves ON (#{_ct.quoted_table_name}.#{primary_key} = leaves.ancestor_id)
        SQL
        _ct.scope_with_order(s.readonly(false))
      end

      def with_ancestor(*ancestors)
        ancestor_ids = ancestors.map { |ea| ea.is_a?(ActiveRecord::Base) ? ea._ct_id : ea }
        scope = ancestor_ids.blank? ? all : joins(:ancestor_hierarchies).
          where("#{_ct.hierarchy_table_name}.ancestor_id" => ancestor_ids).
          where("#{_ct.hierarchy_table_name}.generations > 0").
          readonly(false)
        _ct.scope_with_order(scope)
      end

      def with_descendant(*descendants)
        descendant_ids = descendants.map { |ea| ea.is_a?(ActiveRecord::Base) ? ea._ct_id : ea }
        scope = descendant_ids.blank? ? all : joins(:descendant_hierarchies).
          where("#{_ct.hierarchy_table_name}.descendant_id" => descendant_ids).
          where("#{_ct.hierarchy_table_name}.generations > 0").
          readonly(false)
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
        s = joins(<<-SQL.squish)
          INNER JOIN (
            SELECT #{primary_key} as root_id
            FROM #{_ct.quoted_table_name}
            WHERE #{_ct.quoted_parent_column_name} IS NULL
          ) #{ _ct.t_alias_keyword }  roots ON (1 = 1)
          INNER JOIN (
            SELECT ancestor_id, descendant_id
            FROM #{_ct.quoted_hierarchy_table_name}
            GROUP BY ancestor_id, descendant_id
            HAVING MAX(generations) = #{generation_level.to_i}
          ) #{ _ct.t_alias_keyword }  descendants ON (
            #{_ct.quoted_table_name}.#{primary_key} = descendants.descendant_id
            AND roots.root_id = descendants.ancestor_id
          )
        SQL
        _ct.scope_with_order(s)
      end

      # Find the node whose +ancestry_path+ is +path+
      def find_by_path(path, attributes = {}, parent_id = nil)
        return nil if path.blank?
        path = _ct.build_ancestry_attr_path(path, attributes)
        if path.size > _ct.max_join_tables
          return _ct.find_by_large_path(path, attributes, parent_id)
        end
        scope = where(path.pop)
        last_joined_table = _ct.table_name
        path.reverse.each_with_index do |ea, idx|
          next_joined_table = "p#{idx}"
          scope = scope.joins(<<-SQL.squish)
            INNER JOIN #{_ct.quoted_table_name} #{ _ct.t_alias_keyword } #{next_joined_table}
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
