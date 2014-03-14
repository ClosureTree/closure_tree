require 'active_support/concern'

module ClosureTree
  module HierarchyMaintenance
    extend ActiveSupport::Concern

    included do
      validate :_ct_validate
      before_save :_ct_before_save
      after_save :_ct_after_save
      before_destroy :_ct_before_destroy
    end

    def _ct_skip_cycle_detection!
      @_ct_skip_cycle_detection = true
    end

    def _ct_validate
      if !@_ct_skip_cycle_detection &&
        !new_record? && # don't validate for cycles if we're a new record
        changes[_ct.parent_column_name] && # don't validate for cycles if we didn't change our parent
        parent.present? && # don't validate if we're root
        parent.self_and_ancestors.include?(self) # < this is expensive :\
        errors.add(_ct.parent_column_sym, "You cannot add an ancestor as a descendant")
      end
    end

    def _ct_before_save
      @was_new_record = new_record?
      true # don't cancel the save
    end

    def _ct_after_save
      if changes[_ct.parent_column_name] || @was_new_record
        rebuild!
      end
      if changes[_ct.parent_column_name] && !@was_new_record
        # Resetting the ancestral collections addresses
        # https://github.com/mceachen/closure_tree/issues/68
        ancestor_hierarchies.reload
        self_and_ancestors.reload
      end
      @was_new_record = false # we aren't new anymore.
      true # don't cancel anything.
    end

    def _ct_before_destroy
      _ct.with_advisory_lock do
        delete_hierarchy_references
        if _ct.options[:dependent] == :nullify
          self.class.find(self.id).children.each { |c| c.rebuild! }
        end
      end
      true # don't prevent destruction
    end

    def rebuild!
      _ct.with_advisory_lock do
        delete_hierarchy_references unless @was_new_record
        hierarchy_class.create!(:ancestor => self, :descendant => self, :generations => 0)
        unless root?
          _ct.connection.execute <<-SQL
            INSERT INTO #{_ct.quoted_hierarchy_table_name}
              (ancestor_id, descendant_id, generations)
            SELECT x.ancestor_id, #{_ct.quote(_ct_id)}, x.generations + 1
            FROM #{_ct.quoted_hierarchy_table_name} x
            WHERE x.descendant_id = #{_ct.quote(_ct_parent_id)}
          SQL
        end
        children.each { |c| c.rebuild! }
        _ct_reorder_children if _ct.order_is_numeric?
      end
    end

    def delete_hierarchy_references
      _ct.with_advisory_lock do
        # The crazy double-wrapped sub-subselect works around MySQL's limitation of subselects on the same table that is being mutated.
        # It shouldn't affect performance of postgresql.
        # See http://dev.mysql.com/doc/refman/5.0/en/subquery-errors.html
        # Also: PostgreSQL doesn't support INNER JOIN on DELETE, so we can't use that.
        #_ct.connection.execute <<-SQL
        #  DELETE FROM #{_ct.quoted_hierarchy_table_name}
        #  WHERE descendant_id IN (
        #    SELECT DISTINCT descendant_id
        #    FROM (SELECT descendant_id
        #      FROM #{_ct.quoted_hierarchy_table_name}
        #      WHERE ancestor_id = #{_ct.quote(id)}
        #    ) AS x )
        #    OR descendant_id = #{_ct.quote(id)}
        #SQL

        # This optimized query works way faster on MySQL
        _ct.connection.execute <<-SQL
          DELETE ht.* FROM #{_ct.quoted_hierarchy_table_name} ht JOIN (
            SELECT DISTINCT descendant_id
              FROM #{_ct.quoted_hierarchy_table_name}
              WHERE ancestor_id = #{_ct.quote(id)}
            ) x ON x.descendant_id = ht.descendant_id
        SQL
      end
    end

    module ClassMethods
      # Rebuilds the hierarchy table based on the parent_id column in the database.
      # Note that the hierarchy table will be truncated.
      def rebuild!
        _ct.with_advisory_lock do
          hierarchy_class.delete_all # not destroy_all -- we just want a simple truncate.
          roots.each { |n| n.send(:rebuild!) } # roots just uses the parent_id column, so this is safe.
        end
        nil
      end
    end
  end
end
