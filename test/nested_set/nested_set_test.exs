defmodule ActsAs.NestedSetTest do
  use ExUnit.Case, async: true
  doctest ActsAs.NestedSet

  alias Ecto.Integration.TestRepo

  ########################################
  ### DUMMY
  ########################################

  defmodule Dummy do
    use Ecto.Schema
    import Ecto.Changeset

    schema "dummies" do
      # self join
      belongs_to(:parent, __MODULE__, foreign_key: :parent_id, on_replace: :delete)
      has_many(:children, __MODULE__, foreign_key: :parent_id)

      # nested set
      field :lft, :integer
      field :rgt, :integer
      field :depth, :integer
    end

    use ActsAs.NestedSet

    def changeset(%__MODULE__{} = dummy, attrs) do
      dummy
      |> cast(attrs, [])
    end

    @impl ActsAs.NestedSet
    def new_changeset(%__MODULE__{} = dummy, attrs) do
      dummy
      |> changeset(attrs)
      |> generate_lft_rgt_depth()
    end

    @impl ActsAs.NestedSet
    def child_changeset(%__MODULE__{} = dummy, %__MODULE__{} = parent, attrs) do
      dummy
      |> changeset(attrs)
      |> generate_lft_rgt_depth_from(parent)
    end

    defp generate_lft_rgt_depth(changeset) do
      case changeset do
        %Ecto.Changeset{valid?: true} ->
          lft = get_max_rgt() + 1
          rgt = lft + 1

          changeset
          |> put_change(:depth, 0)
          |> put_change(:lft, lft)
          |> put_change(:rgt, rgt)

        _ ->
          changeset
      end
    end

    defp generate_lft_rgt_depth_from(changeset, parent) do
      case changeset do
        %Ecto.Changeset{valid?: true} ->
          lft = parent.rgt
          rgt = lft + 1

          changeset
          |> put_change(:depth, parent.depth + 1)
          |> put_change(:lft, lft)
          |> put_change(:rgt, rgt)

        _ ->
          changeset
      end
    end

    # In the real implementation, this is delegated to context
    # which knows about repo!
    defp get_max_rgt() do
      # Core.max_rgt()
      (Dummy.max_rgt() |> TestRepo.one()) || 0
    end
  end

  ########################################
  ### DUMMY CONTEXT
  ########################################

  defmodule DummyContext do
    import Ecto.Query, warn: false

    def list_dummies(), do: TestRepo.all(Dummy)

    def get_dummy(id), do: TestRepo.get(Dummy, id)

    def create_dummy(attrs) do
      %Dummy{}
      |> Dummy.insert(attrs)
      |> TestRepo.insert()
    end

    def create_dummy(attrs, parent) do
      parent
      |> Ecto.build_assoc(:children)
      |> Dummy.insert(attrs, parent)
      |> TestRepo.transaction()
      |> case do
        {:ok, %{insert_resource: child}} ->
          {:ok, child}
        {:error, :insert_resource, changeset, _} ->
          {:error, changeset}
      end
    end

    def delete_dummy(%Dummy{} = dummy) do
      {:ok, %{delete_resource: deleted}} = dummy
      |> Dummy.delete()
      |> TestRepo.transaction()

      {:ok, deleted}
    end

    ### Dummy Movements

    def move_to_child_of(%Dummy{} = dummy, parent) when is_nil(parent), do: move_to_root(dummy)
    def move_to_child_of(%Dummy{} = dummy, %Dummy{} = parent) do
      dummy = dummy
      |> ensure_preload(:parent)
      # |> ensure_preload(:children)

      # parent = parent
      # |> ensure_preload(:parent)
      # |> ensure_preload(:children)

      case Dummy.move_to_child_of(dummy, parent) do
        {:error, reason} -> {:error, reason}
        %Ecto.Multi{} = multi -> TestRepo.transaction(multi)
      end
    end

    def move_to_root(%Dummy{} = dummy) do
      dummy
      |> move_to_right_of(last_root())

      # last_root()
      # |> move_to_right_of(dummy)
    end

    def move_to_left_of(%Dummy{} = dummy, %Dummy{} = brother) do
      dummy = dummy
      |> ensure_preload(:parent)
      # |> ensure_preload(:children)

      brother = brother
      |> ensure_preload(:parent)
      # |> ensure_preload(:children)

      case Dummy.move_to_left_of(dummy, brother) do
        {:error, reason} -> {:error, reason}
        %Ecto.Multi{} = multi -> TestRepo.transaction(multi)
      end
    end

    def move_to_right_of(%Dummy{} = dummy, %Dummy{} = brother) do
      dummy = dummy
      |> ensure_preload(:parent)
      # |> ensure_preload(:children)

      brother = brother
      |> ensure_preload(:parent)
      # |> ensure_preload(:children)

      case Dummy.move_to_right_of(dummy, brother) do
        {:error, reason} -> {:error, reason}
        %Ecto.Multi{} = multi -> TestRepo.transaction(multi)
      end
    end

    defp last_root() do
      Dummy.roots()
      |> TestRepo.all()
      |> List.last
    end

    defp ensure_preload(dummy, assoc) do
      case Ecto.assoc_loaded?(Map.get(dummy, assoc)) do
        true -> dummy
        false -> dummy |> TestRepo.preload(assoc)
      end
    end
  end

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
      {:ok, dummy} = DummyContext.create_dummy(%{})

      assert dummy.lft == 1
      assert dummy.rgt == 2
      assert dummy.depth == 0
    end

    test "creates multiple with nested set metadata" do
      {:ok, dummy} = DummyContext.create_dummy(%{})
      {:ok, dummy2} = DummyContext.create_dummy(%{})
      assert dummy.lft == 1
      assert dummy.rgt == 2
      assert dummy.depth == 0

      assert dummy2.lft == 3
      assert dummy2.rgt == 4
      assert dummy2.depth == 0
      assert Enum.count(DummyContext.list_dummies) == 2
    end

    test "creates nested with nested set metadata" do
      {:ok, parent} = DummyContext.create_dummy(%{})
      {:ok, child} = DummyContext.create_dummy(%{}, parent)

      assert child.lft == 2
      assert child.rgt == 3
      assert child.depth == 1

      # Reload parent
      parent = DummyContext.get_dummy(parent.id)
      assert parent.lft == 1
      assert parent.rgt == 4
      assert parent.depth == 0
    end


    test "creates multiple level of nested dummy with nested set metadata" do
      {:ok, parent} = DummyContext.create_dummy(%{})
      {:ok, child} = DummyContext.create_dummy(%{}, parent)
      {:ok, subchild} = DummyContext.create_dummy(%{}, child)

      assert subchild.lft == 3
      assert subchild.rgt == 4
      assert subchild.depth == 2

      child = DummyContext.get_dummy(child.id)
      assert child.lft == 2
      assert child.rgt == 5
      assert child.depth == 1

      parent = DummyContext.get_dummy(parent.id)
      assert parent.lft == 1
      assert parent.rgt == 6
      assert parent.depth == 0
    end

    test "deletes an dummy" do
      {:ok, dummy} = DummyContext.create_dummy(%{})
      DummyContext.delete_dummy(dummy)
      assert Enum.count(DummyContext.list_dummies) == 0
    end

    test "deletes an dummy and recalculate tree" do
      {:ok, first} = DummyContext.create_dummy(%{})
      {:ok, second} = DummyContext.create_dummy(%{})

      DummyContext.delete_dummy(first)

      second = DummyContext.get_dummy(second.id)
      assert second.lft == 1
      assert second.rgt == 2
      assert second.depth == 0
    end

    test "deletes a nested dummy and recalculate tree" do
      {:ok, first} = DummyContext.create_dummy(%{})
      {:ok, second} = DummyContext.create_dummy(%{})
      {:ok, _third} = DummyContext.create_dummy(%{}, first)

      # You need to reload to get updated lft and rgt
      first = DummyContext.get_dummy(first.id)
      DummyContext.delete_dummy(first)

      second = DummyContext.get_dummy(second.id)
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
      {:ok, dummy_1} = DummyContext.create_dummy(%{})
      {:ok, dummy_2} = DummyContext.create_dummy(%{})
      {:ok, dummy_3} = DummyContext.create_dummy(%{})
      {:ok, dummy_4} = DummyContext.create_dummy(%{}, dummy_3)

      dummy_3 = DummyContext.get_dummy(dummy_3.id)

      {:ok, dummy_1: dummy_1, dummy_2: dummy_2, dummy_3: dummy_3, dummy_4: dummy_4}
    end

    test "move to child of from right to left", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]

      assert dummy_1.lft == 1
      assert dummy_1.rgt == 2
      assert dummy_2.lft == 3
      assert dummy_2.rgt == 4

      assert {:error, _} = DummyContext.move_to_child_of(dummy_2, dummy_2)

      DummyContext.move_to_child_of(dummy_2, dummy_1)

      dummy_1 = DummyContext.get_dummy(dummy_1.id)
      dummy_2 = DummyContext.get_dummy(dummy_2.id)

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

      DummyContext.move_to_child_of(dummy_1, dummy_2)

      dummy_1 = DummyContext.get_dummy(dummy_1.id)
      dummy_2 = DummyContext.get_dummy(dummy_2.id)

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

      assert {:error, _} = DummyContext.move_to_child_of(dummy_3, dummy_4)

      DummyContext.move_to_child_of(dummy_3, dummy_1)

      # Reload data
      dummy_1 = DummyContext.get_dummy(dummy_1.id)
      dummy_2 = DummyContext.get_dummy(dummy_2.id)
      dummy_3 = DummyContext.get_dummy(dummy_3.id)
      dummy_4 = DummyContext.get_dummy(dummy_4.id)

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

      DummyContext.move_to_right_of(dummy_1, dummy_2)

      # Reload data
      dummy_1 = DummyContext.get_dummy(dummy_1.id)
      dummy_2 = DummyContext.get_dummy(dummy_2.id)

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

      assert {:error, _} = DummyContext.move_to_right_of(dummy_3, dummy_4)

      DummyContext.move_to_right_of(dummy_3, dummy_1)

      # Reload data
      dummy_1 = DummyContext.get_dummy(dummy_1.id)
      dummy_2 = DummyContext.get_dummy(dummy_2.id)
      dummy_3 = DummyContext.get_dummy(dummy_3.id)
      dummy_4 = DummyContext.get_dummy(dummy_4.id)

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

      DummyContext.move_to_left_of(dummy_2, dummy_1)

      # Reload data
      dummy_1 = DummyContext.get_dummy(dummy_1.id)
      dummy_2 = DummyContext.get_dummy(dummy_2.id)

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

      assert {:error, _} = DummyContext.move_to_left_of(dummy_3, dummy_4)

      DummyContext.move_to_left_of(dummy_3, dummy_1)

      # Reload data
      dummy_1 = DummyContext.get_dummy(dummy_1.id)
      dummy_2 = DummyContext.get_dummy(dummy_2.id)
      dummy_3 = DummyContext.get_dummy(dummy_3.id)
      dummy_4 = DummyContext.get_dummy(dummy_4.id)

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

      DummyContext.move_to_root(dummy_4)

      # Reload data
      dummy_3 = DummyContext.get_dummy(dummy_3.id)
      dummy_4 = DummyContext.get_dummy(dummy_4.id)

      assert dummy_3.lft == 5
      assert dummy_3.rgt == 6

      assert dummy_4.lft == 7
      assert dummy_4.rgt == 8
      assert dummy_4.depth == 0
      assert is_nil(dummy_4.parent_id)
    end
  end

  describe "Complex Movements" do
    # test "move to left of (complex)" do
    #   {:ok, dummy_1} = DummyContext.create_dummy(%{})
    #   {:ok, dummy_2} = DummyContext.create_dummy(%{}, dummy_1)
    #   {:ok, dummy_3} = DummyContext.create_dummy(%{})

    #   # Reload data
    #   dummy_1 = DummyContext.get_dummy(dummy_1.id)

    #   assert dummy_1.lft == 1
    #   assert dummy_1.rgt == 4

    #   assert dummy_2.lft == 2
    #   assert dummy_2.rgt == 3
    #   assert dummy_2.depth == 1
    #   assert dummy_2.parent_id == dummy_1.id

    #   DummyContext.move_to_left_of(dummy_2, dummy_3)

    #   # Reload data
    #   dummy_1 = DummyContext.get_dummy(dummy_1.id)
    #   dummy_2 = DummyContext.get_dummy(dummy_2.id)
    #   dummy_3 = DummyContext.get_dummy(dummy_3.id)

    #   assert dummy_1.lft == 1
    #   assert dummy_1.rgt == 2

    #   assert dummy_2.lft == 3
    #   assert dummy_2.rgt == 4
    #   assert dummy_2.depth == 0
    #   assert is_nil(dummy_2.parent_id)

    #   assert dummy_3.lft == 5
    #   assert dummy_3.rgt == 6
    # end
  end

end
