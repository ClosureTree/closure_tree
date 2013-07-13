module ClosureTree
  module Finders
    extend ActiveSupport::Concern

    # Find a child node whose +ancestry_path+ minus self.ancestry_path is +path+.
    def find_by_path(path, attributes = {})
      return self if path.empty?
      self.class.find_by_path(path, attributes, id)
    end

    # Find a child node whose +ancestry_path+ minus self.ancestry_path is +path+
    def find_or_create_by_path(path, attributes = {}, find_before_lock = true)
      attributes[:type] ||= self.type if _ct.subclass? && _ct.has_type?
      (find_before_lock && find_by_path(path, attributes)) || begin
        _ct.with_advisory_lock do
          subpath = path.is_a?(Enumerable) ? path.dup : [path]
          child_name = subpath.shift
          return self unless child_name
          child = if ActiveRecord::VERSION::MAJOR <= 3 && ActiveRecord::VERSION::MINOR < 2
            attrs = attributes.merge(_ct.name_sym => child_name)
            # shenanigans because children.create is bound to the superclass
            # (in the case of polymorphism):
            self.children.where(attrs).first || begin
              self.class.new(attrs).tap { |ea| self.children << ea }
            end
          else
            self.children.where(_ct.name_sym => child_name).first_or_create(attributes)
          end
          child.find_or_create_by_path(subpath, attributes, false)
        end
      end
    end

    def find_all_by_generation(generation_level)
      s = _ct.base_class.joins(<<-SQL)
        INNER JOIN (
          SELECT descendant_id
          FROM #{_ct.quoted_hierarchy_table_name}
          WHERE ancestor_id = #{_ct.quote(self.id)}
          GROUP BY 1
          HAVING MAX(#{_ct.quoted_hierarchy_table_name}.generations) = #{generation_level.to_i}
        ) AS descendants ON (#{_ct.quoted_table_name}.#{_ct.base_class.primary_key} = descendants.descendant_id)
      SQL
      _ct.scope_with_order(s)
    end

    def without_self(scope)
      scope.without(self)
    end

    module ClassMethods

      def without(instance)
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
        s = joins(<<-SQL)
          INNER JOIN (
            SELECT ancestor_id
            FROM #{_ct.quoted_hierarchy_table_name}
            GROUP BY 1
            HAVING MAX(#{_ct.quoted_hierarchy_table_name}.generations) = 0
          ) AS leaves ON (#{_ct.quoted_table_name}.#{primary_key} = leaves.ancestor_id)
        SQL
        _ct.scope_with_order(s.readonly(false))
      end

      def with_ancestor(*ancestors)
        ancestor_ids = ancestors.map { |ea| ea.is_a?(ActiveRecord::Base) ? ea._ct_id : ea }
        scope = ancestor_ids.blank? ? scoped : joins(:ancestor_hierarchies).
          where("#{_ct.hierarchy_table_name}.ancestor_id" => ancestor_ids).
          where("#{_ct.hierarchy_table_name}.generations > 0").
          readonly(false)
        _ct.scope_with_order(scope)
      end

      def find_all_by_generation(generation_level)
        s = joins(<<-SQL)
          INNER JOIN (
            SELECT #{primary_key} as root_id
            FROM #{_ct.quoted_table_name}
            WHERE #{_ct.quoted_parent_column_name} IS NULL
          ) AS roots ON (1 = 1)
          INNER JOIN (
            SELECT ancestor_id, descendant_id
            FROM #{_ct.quoted_hierarchy_table_name}
            GROUP BY 1, 2
            HAVING MAX(generations) = #{generation_level.to_i}
          ) AS descendants ON (
            #{_ct.quoted_table_name}.#{primary_key} = descendants.descendant_id
            AND roots.root_id = descendants.ancestor_id
          )
        SQL
        _ct.scope_with_order(s)
      end

      def ct_scoped_attributes(scope, attributes, target_table = table_name)
        attributes.inject(scope) do |scope, pair|
          scope.where("#{target_table}.#{pair.first}" => pair.last)
        end
      end

      # Find the node whose +ancestry_path+ is +path+
      def find_by_path(path, attributes = {}, parent_id = nil)
        path = path.is_a?(Enumerable) ? path.dup : [path]
        scope = where(_ct.name_sym => path.pop).readonly(false)
        scope = ct_scoped_attributes(scope, attributes)
        last_joined_table = _ct.table_name
        path.reverse.each_with_index do |ea, idx|
          next_joined_table = "p#{idx}"
          scope = scope.joins(<<-SQL)
            INNER JOIN #{_ct.quoted_table_name} AS #{next_joined_table}
              ON #{next_joined_table}.#{_ct.quoted_id_column_name} =
                #{connection.quote_table_name(last_joined_table)}.#{_ct.quoted_parent_column_name}
          SQL
          scope = scope.where("#{next_joined_table}.#{_ct.name_column}" => ea)
          scope = ct_scoped_attributes(scope, attributes, next_joined_table)
          last_joined_table = next_joined_table
        end
        scope = scope.where("#{last_joined_table}.#{_ct.parent_column_name}" => parent_id)
        scope.first
      end

      # Find or create nodes such that the +ancestry_path+ is +path+
      def find_or_create_by_path(path, attributes = {})
        find_by_path(path, attributes) || begin
          subpath = path.dup
          root_name = subpath.shift
          _ct.with_advisory_lock do
            # shenanigans because find_or_create can't infer that we want the same class as this:
            # Note that roots will already be constrained to this subclass (in the case of polymorphism):
            attrs = attributes.merge(_ct.name_sym => root_name)
            root = roots.where(attrs).first || roots.create!(attrs)
            root.find_or_create_by_path(subpath, attributes)
          end
        end
      end
    end
  end
end
