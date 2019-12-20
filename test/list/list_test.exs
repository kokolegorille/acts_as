defmodule ActsAs.ListTest do
  use ExUnit.Case, async: true
  doctest ActsAs.List

  alias Ecto.Integration.TestRepo

  # DummyList && DummyListContext are defined in test_helper!

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
    setup do
      {:ok, parent} = DummyNSContext.create_dummy(%{})
      {:ok, parent: parent}
    end

    test "creates with list metadata", context do
      parent = context[:parent]
      {:ok, dummy} = DummyListContext.create_dummy(%{}, parent)
      assert dummy.position == 1
    end

    test "creates multiple lists with metadata", context do
      parent = context[:parent]
      {:ok, dummy} = DummyListContext.create_dummy(%{}, parent)
      {:ok, dummy2} = DummyListContext.create_dummy(%{}, parent)
      assert dummy.position == 1
      assert dummy2.position == 2
    end

    test "delete update list metadata", context do
      parent = context[:parent]
      {:ok, dummy_1} = DummyListContext.create_dummy(%{}, parent)
      {:ok, dummy_2} = DummyListContext.create_dummy(%{}, parent)
      {:ok, dummy_3} = DummyListContext.create_dummy(%{}, parent)
      assert dummy_1.position == 1
      assert dummy_2.position == 2
      assert dummy_3.position == 3
      assert DummyList.get_max_position(parent.id) == 3

      DummyListContext.delete_dummy(dummy_2)
      dummy_3 = DummyListContext.get_dummy(dummy_3.id)
      assert dummy_3.position == 2
    end
  end

  describe "Movement" do
    setup do
      {:ok, parent} = DummyNSContext.create_dummy(%{})

      {:ok, dummy_1} = DummyListContext.create_dummy(%{}, parent)
      {:ok, dummy_2} = DummyListContext.create_dummy(%{}, parent)
      {:ok, dummy_3} = DummyListContext.create_dummy(%{}, parent)
      {:ok, dummy_4} = DummyListContext.create_dummy(%{}, parent)
      {:ok, dummy_5} = DummyListContext.create_dummy(%{}, parent)

      {
        :ok, dummy_1: dummy_1, dummy_2: dummy_2,
        dummy_3: dummy_3, dummy_4: dummy_4, dummy_5: dummy_5,
        scope_value: parent.id
      }
    end

    test "check context", context do
      assert context[:dummy_1].position == 1
      assert context[:dummy_2].position == 2
      assert context[:dummy_3].position == 3
      assert context[:dummy_4].position == 4
      assert context[:dummy_5].position == 5
    end

    test "cannot be moved to itself", context do
      assert {:error, _} = DummyListContext.move_from_to(
        context[:dummy_1], context[:dummy_1], context[:scope_value]
      )
    end

    test "can be moved down", context do
      DummyListContext.move_from_to(
        context[:dummy_5], context[:dummy_2], context[:scope_value]
      )
      assert DummyListContext.get_dummy(context[:dummy_1].id).position == 1
      assert DummyListContext.get_dummy(context[:dummy_2].id).position == 3
      assert DummyListContext.get_dummy(context[:dummy_4].id).position == 5
      assert DummyListContext.get_dummy(context[:dummy_5].id).position == 2
    end

    test "can be moved up", context do
      DummyListContext.move_from_to(
        context[:dummy_2], context[:dummy_4], context[:scope_value]
      )
      assert DummyListContext.get_dummy(context[:dummy_1].id).position == 1
      assert DummyListContext.get_dummy(context[:dummy_2].id).position == 4
      assert DummyListContext.get_dummy(context[:dummy_4].id).position == 3
      assert DummyListContext.get_dummy(context[:dummy_5].id).position == 5
    end
  end
end
