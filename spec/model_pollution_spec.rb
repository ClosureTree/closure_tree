require 'spec_helper'

class TreelessLabel < ActiveRecord::Base
  self.table_name = "labels"
end

describe "model instances" do

  def without_ar_callback_methods(methods)
    methods.reject { |ea| ea.to_s =~ /^_run.*_callbacks$/ }
  end

  it "doesn't remove methods" do
    without_ar_callback_methods(TreelessLabel.new.methods - Label.new.methods).should == []
  end

  it "only adds advertised methods" do
    public_interface = %w{
      add_child
      add_sibling
      ancestor_hierarchies
      ancestor_hierarchy_ids
      ancestor_ids
      ancestors
      ancestry_path
      append_sibling
      child?
      depth
      descendant_ids
      descendants
      find_all_by_generation
      find_by_path
      find_or_create_by_path
      hash_tree
      hash_tree_scope
      leaf?
      leaves
      parent
      parent_id
      root
      root?
      self_and_ancestor_ids
      self_and_ancestors
      self_and_descendant_ids
      self_and_descendants
      self_and_descendants_preordered
      self_and_siblings
      siblings
      siblings_after
      siblings_before
    }.map { |i| i.to_sym }
    ct_added_methods = without_ar_callback_methods(Label.new.methods - TreelessLabel.new.methods)
    unimplemented_api_methods = public_interface - ct_added_methods
    unimplemented_api_methods.should == []
  end

  it "doesn't add closure_tree implementation-specific gunk into the model's namespace" do
    ct_specific_methods = %w{
      _parent_id
      after_add_for_ancestor_hierarchies=
      after_add_for_ancestor_hierarchies?
      after_add_for_descendant_hierarchies
      after_add_for_descendant_hierarchies=
      after_add_for_descendant_hierarchies?
      after_add_for_self_and_ancestors
      after_add_for_self_and_ancestors=
      after_add_for_self_and_ancestors?
      after_add_for_self_and_descendants
      after_add_for_self_and_descendants=
      after_add_for_self_and_descendants?
      after_remove_for_ancestor_hierarchies
      after_remove_for_ancestor_hierarchies=
      after_remove_for_ancestor_hierarchies?
      after_remove_for_descendant_hierarchies
      after_remove_for_descendant_hierarchies=
      after_remove_for_descendant_hierarchies?
      after_remove_for_self_and_ancestors
      after_remove_for_self_and_ancestors=
      after_remove_for_self_and_ancestors?
      after_remove_for_self_and_descendants
      after_remove_for_self_and_descendants=
      after_remove_for_self_and_descendants?
      ancestor_hierarchies=
      ancestor_hierarchy_ids=
      append_order
      closure_tree_options
      closure_tree_options=
      closure_tree_options?
      ct_after_save
      attribute_names
      base_class
      ct_before_destroy
      ct_before_save
      ct_class
      has_type?
      ct_quote
      subclass?
      table_name
      ct_validate
      ct_with_advisory_lock
      ids_from
      name_column
      name_sym
      order_column
      order_column_sym
      order_is_numeric
      order_option
      order_value
      order_value=
      parent_column_name
      parent_column_sym
      quoted_hierarchy_table_name
      quoted_name_column
      quoted_order_column
      quoted_parent_column_name
      rebuild!
      remove_prefix_and_suffix
      self_and_ancestor_ids=
      self_and_descendants=
      short_hierarchy_class_name
      with_order_option
      without_self
    }.map { |i| i.to_sym }
    ct_added_methods = without_ar_callback_methods(Label.new.methods - TreelessLabel.new.methods)
    noisy_model_methods = ct_added_methods & ct_specific_methods
    unless noisy_model_methods.empty?
      puts "BOO: We still have #{noisy_model_methods.size} methods polluting people's models."
    end
  end
end
