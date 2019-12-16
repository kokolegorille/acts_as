defmodule ActsAs.NestedSetTest do
  use ExUnit.Case, async: true
  doctest ActsAs.NestedSet

  alias Ecto.Integration.TestRepo

  # DummyNS && DummyNSContext are defined in test_helper!

  ########################################
  ### SETUP
  ########################################

  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(TestRepo)
  end

  ########################################
  ### CRUD
  ########################################

  describe "Crud with a fake context" do
    test "creates with nested set metadata" do
      {:ok, dummy} = DummyNSContext.create_dummy(%{})

      assert dummy.lft == 1
      assert dummy.rgt == 2
      assert dummy.depth == 0
    end

    test "creates multiple with nested set metadata" do
      {:ok, dummy} = DummyNSContext.create_dummy(%{})
      {:ok, dummy2} = DummyNSContext.create_dummy(%{})
      assert dummy.lft == 1
      assert dummy.rgt == 2
      assert dummy.depth == 0

      assert dummy2.lft == 3
      assert dummy2.rgt == 4
      assert dummy2.depth == 0
      assert Enum.count(DummyNSContext.list_dummies) == 2
    end

    test "creates nested with nested set metadata" do
      {:ok, parent} = DummyNSContext.create_dummy(%{})
      {:ok, child} = DummyNSContext.create_dummy(%{}, parent)

      assert child.lft == 2
      assert child.rgt == 3
      assert child.depth == 1

      # Reload parent
      parent = DummyNSContext.get_dummy(parent.id)
      assert parent.lft == 1
      assert parent.rgt == 4
      assert parent.depth == 0
    end


    test "creates multiple level of nested dummy with nested set metadata" do
      {:ok, parent} = DummyNSContext.create_dummy(%{})
      {:ok, child} = DummyNSContext.create_dummy(%{}, parent)
      {:ok, subchild} = DummyNSContext.create_dummy(%{}, child)

      assert subchild.lft == 3
      assert subchild.rgt == 4
      assert subchild.depth == 2

      child = DummyNSContext.get_dummy(child.id)
      assert child.lft == 2
      assert child.rgt == 5
      assert child.depth == 1

      parent = DummyNSContext.get_dummy(parent.id)
      assert parent.lft == 1
      assert parent.rgt == 6
      assert parent.depth == 0
    end

    test "deletes an dummy" do
      {:ok, dummy} = DummyNSContext.create_dummy(%{})
      DummyNSContext.delete_dummy(dummy)
      assert DummyNSContext.list_dummies == []
    end

    test "deletes an dummy and recalculate tree" do
      {:ok, first} = DummyNSContext.create_dummy(%{})
      {:ok, second} = DummyNSContext.create_dummy(%{})

      DummyNSContext.delete_dummy(first)

      second = DummyNSContext.get_dummy(second.id)
      assert second.lft == 1
      assert second.rgt == 2
      assert second.depth == 0
    end

    test "deletes a nested dummy and recalculate tree" do
      {:ok, first} = DummyNSContext.create_dummy(%{})
      {:ok, second} = DummyNSContext.create_dummy(%{})
      {:ok, _third} = DummyNSContext.create_dummy(%{}, first)

      # You need to reload to get updated lft and rgt
      first = DummyNSContext.get_dummy(first.id)
      DummyNSContext.delete_dummy(first)

      second = DummyNSContext.get_dummy(second.id)
      assert second.lft == 1
      assert second.rgt == 2
      assert second.depth == 0
    end
  end

  ########################################
  ### MOVEMENTS
  ########################################

  describe "Movements" do
    setup do
      {:ok, dummy_1} = DummyNSContext.create_dummy(%{})
      {:ok, dummy_2} = DummyNSContext.create_dummy(%{})
      {:ok, dummy_3} = DummyNSContext.create_dummy(%{})
      {:ok, dummy_4} = DummyNSContext.create_dummy(%{}, dummy_3)

      dummy_3 = DummyNSContext.get_dummy(dummy_3.id)

      {:ok, dummy_1: dummy_1, dummy_2: dummy_2, dummy_3: dummy_3, dummy_4: dummy_4}
    end

    test "move to child of from right to left", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]

      assert dummy_1.lft == 1
      assert dummy_1.rgt == 2
      assert dummy_2.lft == 3
      assert dummy_2.rgt == 4

      assert {:error, _} = DummyNSContext.move_to_child_of(dummy_2, dummy_2)

      DummyNSContext.move_to_child_of(dummy_2, dummy_1)

      dummy_1 = DummyNSContext.get_dummy(dummy_1.id)
      dummy_2 = DummyNSContext.get_dummy(dummy_2.id)

      assert dummy_1.lft == 1
      assert dummy_1.rgt == 4
      assert dummy_2.lft == 2
      assert dummy_2.rgt == 3
      assert dummy_2.parent_id == dummy_1.id
      assert dummy_2.depth == 1
    end

    test "move to child of from left to right", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]

      assert dummy_1.lft == 1
      assert dummy_1.rgt == 2
      assert dummy_2.lft == 3
      assert dummy_2.rgt == 4

      DummyNSContext.move_to_child_of(dummy_1, dummy_2)

      dummy_1 = DummyNSContext.get_dummy(dummy_1.id)
      dummy_2 = DummyNSContext.get_dummy(dummy_2.id)

      assert dummy_1.lft == 2
      assert dummy_1.rgt == 3
      assert dummy_2.lft == 1
      assert dummy_2.rgt == 4
      assert dummy_1.parent_id == dummy_2.id
      assert dummy_1.depth == 1
    end

    test "move nested to child of", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]
      dummy_3 = context[:dummy_3]
      dummy_4 = context[:dummy_4]

      assert {:error, _} = DummyNSContext.move_to_child_of(dummy_3, dummy_4)

      DummyNSContext.move_to_child_of(dummy_3, dummy_1)

      # Reload data
      dummy_1 = DummyNSContext.get_dummy(dummy_1.id)
      dummy_2 = DummyNSContext.get_dummy(dummy_2.id)
      dummy_3 = DummyNSContext.get_dummy(dummy_3.id)
      dummy_4 = DummyNSContext.get_dummy(dummy_4.id)

      assert dummy_1.lft == 1
      assert dummy_1.rgt == 6
      assert dummy_1.depth == 0
      assert is_nil(dummy_1.parent_id)

      assert dummy_2.lft == 7
      assert dummy_2.rgt == 8
      assert dummy_2.depth == 0
      assert is_nil(dummy_2.parent_id)

      assert dummy_3.lft == 2
      assert dummy_3.rgt == 5
      assert dummy_3.depth == 1
      assert dummy_3.parent_id == dummy_1.id

      assert dummy_4.lft == 3
      assert dummy_4.rgt == 4
      assert dummy_4.depth == 2
      assert dummy_4.parent_id == dummy_3.id
    end

    test "move to right of", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]

      DummyNSContext.move_to_right_of(dummy_1, dummy_2)

      # Reload data
      dummy_1 = DummyNSContext.get_dummy(dummy_1.id)
      dummy_2 = DummyNSContext.get_dummy(dummy_2.id)

      assert dummy_1.lft == 3
      assert dummy_1.rgt == 4

      assert dummy_2.lft == 1
      assert dummy_2.rgt == 2
    end

    test "move nested to right of", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]
      dummy_3 = context[:dummy_3]
      dummy_4 = context[:dummy_4]

      assert {:error, _} = DummyNSContext.move_to_right_of(dummy_3, dummy_4)

      DummyNSContext.move_to_right_of(dummy_3, dummy_1)

      # Reload data
      dummy_1 = DummyNSContext.get_dummy(dummy_1.id)
      dummy_2 = DummyNSContext.get_dummy(dummy_2.id)
      dummy_3 = DummyNSContext.get_dummy(dummy_3.id)
      dummy_4 = DummyNSContext.get_dummy(dummy_4.id)

      assert dummy_1.lft == 1
      assert dummy_1.rgt == 2
      assert dummy_1.depth == 0
      assert is_nil(dummy_1.parent_id)

      assert dummy_2.lft == 7
      assert dummy_2.rgt == 8
      assert dummy_2.depth == 0
      assert is_nil(dummy_1.parent_id)

      assert dummy_3.lft == 3
      assert dummy_3.rgt == 6
      assert dummy_3.depth == 0
      assert is_nil(dummy_1.parent_id)

      assert dummy_4.lft == 4
      assert dummy_4.rgt == 5
      assert dummy_4.depth == 1
      assert dummy_4.parent_id == dummy_3.id
    end

    test "move to left of", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]

      DummyNSContext.move_to_left_of(dummy_2, dummy_1)

      # Reload data
      dummy_1 = DummyNSContext.get_dummy(dummy_1.id)
      dummy_2 = DummyNSContext.get_dummy(dummy_2.id)

      assert dummy_1.lft == 3
      assert dummy_1.rgt == 4

      assert dummy_2.lft == 1
      assert dummy_2.rgt == 2
    end

    test "move nested to left of", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]
      dummy_3 = context[:dummy_3]
      dummy_4 = context[:dummy_4]

      assert {:error, _} = DummyNSContext.move_to_left_of(dummy_3, dummy_4)

      DummyNSContext.move_to_left_of(dummy_3, dummy_1)

      # Reload data
      dummy_1 = DummyNSContext.get_dummy(dummy_1.id)
      dummy_2 = DummyNSContext.get_dummy(dummy_2.id)
      dummy_3 = DummyNSContext.get_dummy(dummy_3.id)
      dummy_4 = DummyNSContext.get_dummy(dummy_4.id)

      assert dummy_1.lft == 5
      assert dummy_1.rgt == 6
      assert dummy_1.depth == 0
      assert is_nil(dummy_1.parent_id)

      assert dummy_2.lft == 7
      assert dummy_2.rgt == 8
      assert dummy_2.depth == 0
      assert is_nil(dummy_1.parent_id)

      assert dummy_3.lft == 1
      assert dummy_3.rgt == 4
      assert dummy_3.depth == 0
      assert is_nil(dummy_1.parent_id)

      assert dummy_4.lft == 2
      assert dummy_4.rgt == 3
      assert dummy_4.depth == 1
      assert dummy_4.parent_id == dummy_3.id
    end

    test "Move to root", context do
      dummy_3 = context[:dummy_3]
      dummy_4 = context[:dummy_4]

      DummyNSContext.move_to_root(dummy_4)

      # Reload data
      dummy_3 = DummyNSContext.get_dummy(dummy_3.id)
      dummy_4 = DummyNSContext.get_dummy(dummy_4.id)

      assert dummy_3.lft == 5
      assert dummy_3.rgt == 6

      assert dummy_4.lft == 7
      assert dummy_4.rgt == 8
      assert dummy_4.depth == 0
      assert is_nil(dummy_4.parent_id)
    end
  end

  describe "Complex Movements" do
    test "move to left of (complex)" do
      {:ok, dummy_1} = DummyNSContext.create_dummy(%{})
      {:ok, dummy_2} = DummyNSContext.create_dummy(%{}, dummy_1)
      {:ok, dummy_3} = DummyNSContext.create_dummy(%{})

      # Reload data
      dummy_1 = DummyNSContext.get_dummy(dummy_1.id)

      assert dummy_1.lft == 1
      assert dummy_1.rgt == 4

      assert dummy_2.lft == 2
      assert dummy_2.rgt == 3
      assert dummy_2.depth == 1
      assert dummy_2.parent_id == dummy_1.id

      DummyNSContext.move_to_left_of(dummy_2, dummy_3)

      # Reload data
      dummy_1 = DummyNSContext.get_dummy(dummy_1.id)
      dummy_2 = DummyNSContext.get_dummy(dummy_2.id)
      dummy_3 = DummyNSContext.get_dummy(dummy_3.id)

      assert dummy_1.lft == 1
      assert dummy_1.rgt == 2

      assert dummy_2.lft == 3
      assert dummy_2.rgt == 4
      assert dummy_2.depth == 0
      assert is_nil(dummy_2.parent_id)

      assert dummy_3.lft == 5
      assert dummy_3.rgt == 6
    end
  end

  describe "Predicates" do
    setup do
      {:ok, dummy_1} = DummyNSContext.create_dummy(%{})
      {:ok, dummy_2} = DummyNSContext.create_dummy(%{})
      {:ok, dummy_3} = DummyNSContext.create_dummy(%{})
      {:ok, dummy_4} = DummyNSContext.create_dummy(%{}, dummy_2)

      dummy_2 = DummyNSContext.get_dummy(dummy_2.id)
      dummy_3 = DummyNSContext.get_dummy(dummy_3.id)

      {:ok, dummy_1: dummy_1, dummy_2: dummy_2, dummy_3: dummy_3, dummy_4: dummy_4}
    end

    test "root?", context do
      assert DummyNSContext.root?(context[:dummy_1]) == true
      assert DummyNSContext.root?(context[:dummy_2]) == true
      assert DummyNSContext.root?(context[:dummy_3]) == true
      assert DummyNSContext.root?(context[:dummy_4]) == false
    end

    test "child?", context do
      assert DummyNSContext.child?(context[:dummy_1]) == false
      assert DummyNSContext.child?(context[:dummy_2]) == false
      assert DummyNSContext.child?(context[:dummy_3]) == false
      assert DummyNSContext.child?(context[:dummy_4]) == true
    end

    test "leaf?", context do
      assert DummyNSContext.leaf?(context[:dummy_1]) == true
      assert DummyNSContext.leaf?(context[:dummy_2]) == false
      assert DummyNSContext.leaf?(context[:dummy_3]) == true
      assert DummyNSContext.leaf?(context[:dummy_4]) == true
    end

    test "is_ancestor_of?", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]
      dummy_3 = context[:dummy_3]
      dummy_4 = context[:dummy_4]
      assert DummyNSContext.is_ancestor_of?(dummy_4, dummy_4) == false
      assert DummyNSContext.is_ancestor_of?(dummy_2, dummy_4) == true
      assert DummyNSContext.is_ancestor_of?(dummy_4, dummy_2) == false
      assert DummyNSContext.is_ancestor_of?(dummy_1, dummy_4) == false
      assert DummyNSContext.is_ancestor_of?(dummy_3, dummy_4) == false
    end

    test "is_or_is_ancestor_of?", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]
      dummy_3 = context[:dummy_3]
      dummy_4 = context[:dummy_4]
      assert DummyNSContext.is_or_is_ancestor_of?(dummy_4, dummy_4) == true
      assert DummyNSContext.is_or_is_ancestor_of?(dummy_2, dummy_4) == true
      assert DummyNSContext.is_or_is_ancestor_of?(dummy_4, dummy_2) == false
      assert DummyNSContext.is_or_is_ancestor_of?(dummy_1, dummy_4) == false
      assert DummyNSContext.is_or_is_ancestor_of?(dummy_3, dummy_4) == false
    end

    test "is_descendant_of?", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]
      dummy_3 = context[:dummy_3]
      dummy_4 = context[:dummy_4]
      assert DummyNSContext.is_descendant_of?(dummy_4, dummy_4) == false
      assert DummyNSContext.is_descendant_of?(dummy_4, dummy_2) == true
      assert DummyNSContext.is_descendant_of?(dummy_2, dummy_4) == false
      assert DummyNSContext.is_descendant_of?(dummy_4, dummy_1) == false
      assert DummyNSContext.is_descendant_of?(dummy_4, dummy_3) == false
    end

    test "is_or_is_descendant_of?", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]
      dummy_3 = context[:dummy_3]
      dummy_4 = context[:dummy_4]
      assert DummyNSContext.is_or_is_descendant_of?(dummy_4, dummy_4) == true
      assert DummyNSContext.is_or_is_descendant_of?(dummy_4, dummy_2) == true
      assert DummyNSContext.is_or_is_descendant_of?(dummy_2, dummy_4) == false
      assert DummyNSContext.is_or_is_descendant_of?(dummy_4, dummy_1) == false
      assert DummyNSContext.is_or_is_descendant_of?(dummy_4, dummy_3) == false
    end
  end

  describe "Queries" do
    setup do
      {:ok, dummy_1} = DummyNSContext.create_dummy(%{title: "first"})
      {:ok, dummy_2} = DummyNSContext.create_dummy(%{title: "second"})
      {:ok, dummy_3} = DummyNSContext.create_dummy(%{title: "third"})
      {:ok, dummy_4} = DummyNSContext.create_dummy(%{title: "fourth"}, dummy_2)
      {:ok, dummy_5} = DummyNSContext.create_dummy(%{title: "fourth"}, dummy_4)

      dummy_2 = DummyNSContext.get_dummy(dummy_2.id)
      dummy_3 = DummyNSContext.get_dummy(dummy_3.id)
      dummy_4 = DummyNSContext.get_dummy(dummy_4.id)

      {:ok, dummy_1: dummy_1, dummy_2: dummy_2, dummy_3: dummy_3, dummy_4: dummy_4, dummy_5: dummy_5}
    end

    test "root", context do
      assert DummyNSContext.root == context[:dummy_1]
    end

    test "root of", context do
      assert DummyNSContext.root(context[:dummy_4]) == context[:dummy_2]
      assert DummyNSContext.root(context[:dummy_5]) == context[:dummy_2]
      assert DummyNSContext.root(context[:dummy_1]) == context[:dummy_1]
    end

    test "roots", context do
      assert DummyNSContext.roots == [context[:dummy_1], context[:dummy_2], context[:dummy_3]]
    end

    # Previously, was check level.
    test "Check depth", context do
      assert context[:dummy_1].depth == 0
      assert context[:dummy_2].depth == 0
      assert context[:dummy_3].depth == 0
      assert context[:dummy_4].depth == 1
      assert context[:dummy_5].depth == 2
    end

    test "ancestors", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]
      dummy_3 = context[:dummy_3]
      dummy_4 = context[:dummy_4]
      dummy_5 = context[:dummy_5]
      assert DummyNSContext.ancestors(dummy_1) == []
      assert DummyNSContext.ancestors(dummy_2) == []
      assert DummyNSContext.ancestors(dummy_3) == []
      assert DummyNSContext.ancestors(dummy_4) == [dummy_2]
      assert DummyNSContext.ancestors(dummy_5) == [dummy_2, dummy_4]
    end

    test "self and ancestors", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]
      dummy_3 = context[:dummy_3]
      dummy_4 = context[:dummy_4]
      dummy_5 = context[:dummy_5]
      assert DummyNSContext.self_and_ancestors(dummy_1) == [dummy_1]
      assert DummyNSContext.self_and_ancestors(dummy_2) == [dummy_2]
      assert DummyNSContext.self_and_ancestors(dummy_3) == [dummy_3]
      assert DummyNSContext.self_and_ancestors(dummy_4) == [dummy_2, dummy_4]

      # THIS TEST FAILS BECAUSE dummy_5 has preloaded data!
      # assert DummyNSContext.self_and_ancestors(context[:dummy_5]) == [context[:dummy_2], context[:dummy_4], context[:dummy_5]]

      # Test that it looks the same (without testing assoc)
      left = DummyNSContext.self_and_ancestors(dummy_5) |> sanitize()
      right = [dummy_2, dummy_4, dummy_5] |> sanitize()
      assert left == right
    end

    test "siblings", context do
      assert DummyNSContext.siblings(context[:dummy_4]) == []
      assert DummyNSContext.siblings(context[:dummy_5]) == []

      p1 = DummyNSContext.siblings(context[:dummy_1]) |> sanitize()
      p2 = DummyNSContext.siblings(context[:dummy_2]) |> sanitize()
      p3 = DummyNSContext.siblings(context[:dummy_3]) |> sanitize()

      assert p1 == [context[:dummy_2], context[:dummy_3]] |> sanitize()
      assert p2 == [context[:dummy_1], context[:dummy_3]] |> sanitize()
      assert p3 == [context[:dummy_1], context[:dummy_2]] |> sanitize()
    end

    test "self and siblings", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]
      dummy_3 = context[:dummy_3]
      dummy_4 = context[:dummy_4]
      dummy_5 = context[:dummy_5]
      assert DummyNSContext.self_and_siblings(dummy_4) == [dummy_4]
      assert DummyNSContext.self_and_siblings(dummy_5) |> sanitize() == [dummy_5] |> sanitize()

      p1 = DummyNSContext.self_and_siblings(dummy_1) |> sanitize()
      p2 = DummyNSContext.self_and_siblings(dummy_2) |> sanitize()
      p3 = DummyNSContext.self_and_siblings(dummy_3) |> sanitize()

      assert p1 == p2
      assert p1 == p3
      assert p2 == p3
    end

    test "descendants", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]
      dummy_3 = context[:dummy_3]
      dummy_4 = context[:dummy_4]
      dummy_5 = context[:dummy_5]
      assert DummyNSContext.descendants(dummy_1) == []
      assert DummyNSContext.descendants(dummy_3) == []
      assert DummyNSContext.descendants(dummy_5) == []
      assert DummyNSContext.descendants(dummy_2) |> sanitize() == [dummy_4, dummy_5] |> sanitize()
      assert DummyNSContext.descendants(dummy_4) |> sanitize() == [dummy_5] |> sanitize()
    end

    test "self and descendants", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]
      dummy_3 = context[:dummy_3]
      dummy_4 = context[:dummy_4]
      dummy_5 = context[:dummy_5]
      assert DummyNSContext.self_and_descendants(dummy_1) == [dummy_1]
      assert DummyNSContext.self_and_descendants(dummy_3) == [dummy_3]
      assert DummyNSContext.self_and_descendants(dummy_5) |> sanitize() == [dummy_5] |> sanitize()
      assert DummyNSContext.self_and_descendants(dummy_2) |> sanitize() == [dummy_2, dummy_4, dummy_5] |> sanitize()
      assert DummyNSContext.self_and_descendants(dummy_4) |> sanitize() == [dummy_4, dummy_5] |> sanitize()
    end
  end

  # Private

  defp sanitize(collection) do
    collection |> Enum.map(fn p -> {p.id, p.lft, p.rgt, p.depth} end)
  end
end
