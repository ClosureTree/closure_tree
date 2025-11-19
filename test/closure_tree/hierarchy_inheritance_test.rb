# frozen_string_literal: true

require 'test_helper'

class HierarchyInheritanceTest < ActiveSupport::TestCase
  # Test for issue #392: Hierarchy class should inherit from same abstract base as model
  # but NOT from STI parent (to avoid inheriting validations/callbacks)
  test 'MetalHierarchy inherits from same connection class as Metal' do
    # Force MetalHierarchy to be loaded
    Metal._ct

    # Metal < ApplicationRecord (abstract connection class)
    # Adamantium < Metal (STI child)
    # MetalHierarchy should inherit from ApplicationRecord, NOT Metal
    assert_equal Metal.superclass, MetalHierarchy.superclass,
      "MetalHierarchy should inherit from same abstract base as Metal (#{Metal.superclass})"

    # Verify it's the abstract class, not the STI parent
    assert MetalHierarchy.superclass.abstract_class?,
      "MetalHierarchy should inherit from abstract class"

    # The hierarchy class should NOT inherit validations from Metal
    assert_not_equal Metal.validators.size, MetalHierarchy.validators.size,
      "MetalHierarchy should not inherit validations from Metal"
  end

  test 'Adamantium inherits has_closure_tree and uses same hierarchy as Metal' do
    # Adamantium < Metal (STI - should inherit has_closure_tree)

    # Verify Adamantium inherited has_closure_tree
    assert_respond_to Adamantium, :_ct, "Adamantium should inherit has_closure_tree from Metal"

    # Both should use the same hierarchy class (MetalHierarchy)
    assert_equal Metal.hierarchy_class, Adamantium.hierarchy_class,
      "Adamantium should use same hierarchy class as Metal (STI)"

    # The hierarchy class should inherit from ApplicationRecord, NOT Metal
    assert_equal ApplicationRecord, MetalHierarchy.superclass,
      "MetalHierarchy should inherit from ApplicationRecord, not Metal"
  end
end
