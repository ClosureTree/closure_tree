module ClosureTree
  module ActiveRecordSupport

    def quote(field)
      connection.quote(field)
    end

    def ensure_fixed_table_name(table_name)
      [
        ActiveRecord::Base.table_name_prefix,
        remove_prefix_and_suffix(table_name),
        ActiveRecord::Base.table_name_suffix
      ].compact.join
    end

    def remove_prefix_and_suffix(table_name)
      pre, suff = ActiveRecord::Base.table_name_prefix, ActiveRecord::Base.table_name_suffix
      if table_name.start_with?(pre) && table_name.end_with?(suff)
        table_name[pre.size..-(suff.size + 1)]
      else
        table_name
      end
    end
  end
end
