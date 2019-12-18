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
      {:ok, dummy} = DummyListContext.create_dummy(%{}, parent)
      {:ok, dummy2} = DummyListContext.create_dummy(%{}, parent)
      {:ok, dummy3} = DummyListContext.create_dummy(%{}, parent)
      assert dummy.position == 1
      assert dummy2.position == 2
      assert dummy3.position == 3
      assert DummyList.get_max_position(parent.id) == 3

      DummyListContext.delete_dummy(dummy2)
      dummy3 = DummyListContext.get_dummy(dummy3.id)
      assert dummy3.position == 2
    end
  end

end
