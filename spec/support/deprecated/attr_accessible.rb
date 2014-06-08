# Delete this file when support for 3.2 is dropped
if ENV['ATTR_ACCESSIBLE'] == '1'
  # turn on whitelisted attributes:
  ActiveRecord::Base.send(:include, ActiveModel::MassAssignmentSecurity)
end