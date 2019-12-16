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
  end

end
