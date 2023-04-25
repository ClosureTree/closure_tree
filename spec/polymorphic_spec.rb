require 'spec_helper'

RSpec.describe 'Polymorphic methods' do
  it 'can have polymorphic parents' do
    parent = Project.create!(name: 'parent')
    child = Project.create!(name: 'child', parent: parent)
    expect(child.parent).to eq(parent)

    expect(parent.descendants).to include(child)
  end

  it 'can have different type children #poly_children' do
    root_parent = Project.create!(name: 'root parent')
    parent = Project.create!(name: 'parent', parent: root_parent)
    child = Task.create!(name: 'child', parent: parent)
    another_child = Task.create!(name: 'child', parent: parent)
    sub_task = Task.create!(name: sub_task, parent: child)

    expect(child.parent).to eq(parent)
    expect(parent.poly_children).to include(child)
    expect(parent.poly_children).to include(another_child)
    expect(root_parent.poly_children).to include(parent)
    expect(child.poly_children).to include(sub_task)
  end

  it 'can have poly_self_and_descendants and poly_descendants' do
    root_parent = Project.create!(name: 'root parent')
    parent = Project.create!(name: 'parent', parent: root_parent)
    child = Task.create!(name: 'child', parent: parent)
    another_child = Task.create!(name: 'child', parent: parent)
    sub_task = Task.create!(name: sub_task, parent: child)

    expect(root_parent.poly_self_and_descendants).to match_array([
      root_parent,
      parent,
      child,
      another_child,
      sub_task,
    ])

    expect(root_parent.poly_descendants).to match_array([
      parent,
      child,
      another_child,
      sub_task,
    ])

    expect(child.poly_descendants).to match_array([
      sub_task,
    ])
  end

  it 'can have poly_self_and_ancestors' do
    root_parent = Project.create!(name: 'root parent')
    parent = Project.create!(name: 'parent', parent: root_parent)
    child = Task.create!(name: 'child', parent: parent)

    expect(child.poly_self_and_ancestors).to match_array([
      child,
      parent,
      root_parent,
    ])

    expect(child.poly_ancestors).to match_array([
      parent,
      root_parent,
    ])
  end
end