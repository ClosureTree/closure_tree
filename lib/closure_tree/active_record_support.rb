# frozen_string_literal: true

module ClosureTree
  module ActiveRecordSupport
    delegate :quote, to: :connection

    def remove_prefix_and_suffix(table_name, model = ActiveRecord::Base)
      pre = model.table_name_prefix
      suff = model.table_name_suffix
      if table_name.start_with?(pre) && table_name.end_with?(suff)
        table_name[pre.size..-(suff.size + 1)]
      else
        table_name
      end
    end
  end
end
