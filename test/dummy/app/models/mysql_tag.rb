# frozen_string_literal: true

class MysqlTag < MysqlRecord
  self.table_name = 'mysql_tags'

  after_save do
    MysqlTagAudit.create(tag_name: name)
    MysqlLabel.create(name: name)
  end
end
