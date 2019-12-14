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
      belongs_to(:parent, __MODULE__, foreign_key: :parent_id, on_replace: :nilify)
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

    ### Dummy Predicates

    defdelegate root?(dummy), to: Dummy
    defdelegate child?(dummy), to: Dummy
    defdelegate leaf?(dummy), to: Dummy
    defdelegate is_ancestor_of?(object, subject), to: Dummy
    defdelegate is_or_is_ancestor_of?(object, subject), to: Dummy
    defdelegate is_descendant_of?(object, subject), to: Dummy
    defdelegate is_or_is_descendant_of?(object, subject), to: Dummy

    ### PAGE QUERIES

    def root, do: Dummy.root |> TestRepo.one
    def root(%Dummy{} = dummy), do: Dummy.root(dummy) |> TestRepo.one

    def roots, do: Dummy.roots() |> TestRepo.all

    def leaves, do: Dummy.leaves |> TestRepo.all

    def ancestors(%Dummy{} = dummy), do: Dummy.ancestors(dummy) |> TestRepo.all

    def self_and_ancestors(%Dummy{} = dummy),
      do: Dummy.self_and_ancestors(dummy) |> TestRepo.all

    def siblings(%Dummy{} = dummy), do: Dummy.siblings(dummy) |> TestRepo.all

    def self_and_siblings(%Dummy{} = dummy),
      do: Dummy.self_and_siblings(dummy) |> TestRepo.all

    def descendants(%Dummy{} = dummy), do: Dummy.descendants(dummy) |> TestRepo.all

    def self_and_descendants(%Dummy{} = dummy),
      do: Dummy.self_and_descendants(dummy) |> TestRepo.all

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

    def move_to_root(%Dummy{depth: 0}), do: {:error, "already at root level"}
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
    test "move to left of (complex)" do
      {:ok, dummy_1} = DummyContext.create_dummy(%{})
      {:ok, dummy_2} = DummyContext.create_dummy(%{}, dummy_1)
      {:ok, dummy_3} = DummyContext.create_dummy(%{})

      # Reload data
      dummy_1 = DummyContext.get_dummy(dummy_1.id)

      assert dummy_1.lft == 1
      assert dummy_1.rgt == 4

      assert dummy_2.lft == 2
      assert dummy_2.rgt == 3
      assert dummy_2.depth == 1
      assert dummy_2.parent_id == dummy_1.id

      DummyContext.move_to_left_of(dummy_2, dummy_3)

      # Reload data
      dummy_1 = DummyContext.get_dummy(dummy_1.id)
      dummy_2 = DummyContext.get_dummy(dummy_2.id)
      dummy_3 = DummyContext.get_dummy(dummy_3.id)

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
      {:ok, dummy_1} = DummyContext.create_dummy(%{})
      {:ok, dummy_2} = DummyContext.create_dummy(%{})
      {:ok, dummy_3} = DummyContext.create_dummy(%{})
      {:ok, dummy_4} = DummyContext.create_dummy(%{}, dummy_2)

      dummy_2 = DummyContext.get_dummy(dummy_2.id)
      dummy_3 = DummyContext.get_dummy(dummy_3.id)

      {:ok, dummy_1: dummy_1, dummy_2: dummy_2, dummy_3: dummy_3, dummy_4: dummy_4}
    end

    test "root?", context do
      assert DummyContext.root?(context[:dummy_1]) == true
      assert DummyContext.root?(context[:dummy_2]) == true
      assert DummyContext.root?(context[:dummy_3]) == true
      assert DummyContext.root?(context[:dummy_4]) == false
    end

    test "child?", context do
      assert DummyContext.child?(context[:dummy_1]) == false
      assert DummyContext.child?(context[:dummy_2]) == false
      assert DummyContext.child?(context[:dummy_3]) == false
      assert DummyContext.child?(context[:dummy_4]) == true
    end

    test "leaf?", context do
      assert DummyContext.leaf?(context[:dummy_1]) == true
      assert DummyContext.leaf?(context[:dummy_2]) == false
      assert DummyContext.leaf?(context[:dummy_3]) == true
      assert DummyContext.leaf?(context[:dummy_4]) == true
    end

    test "is_ancestor_of?", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]
      dummy_3 = context[:dummy_3]
      dummy_4 = context[:dummy_4]
      assert DummyContext.is_ancestor_of?(dummy_4, dummy_4) == false
      assert DummyContext.is_ancestor_of?(dummy_2, dummy_4) == true
      assert DummyContext.is_ancestor_of?(dummy_4, dummy_2) == false
      assert DummyContext.is_ancestor_of?(dummy_1, dummy_4) == false
      assert DummyContext.is_ancestor_of?(dummy_3, dummy_4) == false
    end

    test "is_or_is_ancestor_of?", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]
      dummy_3 = context[:dummy_3]
      dummy_4 = context[:dummy_4]
      assert DummyContext.is_or_is_ancestor_of?(dummy_4, dummy_4) == true
      assert DummyContext.is_or_is_ancestor_of?(dummy_2, dummy_4) == true
      assert DummyContext.is_or_is_ancestor_of?(dummy_4, dummy_2) == false
      assert DummyContext.is_or_is_ancestor_of?(dummy_1, dummy_4) == false
      assert DummyContext.is_or_is_ancestor_of?(dummy_3, dummy_4) == false
    end

    test "is_descendant_of?", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]
      dummy_3 = context[:dummy_3]
      dummy_4 = context[:dummy_4]
      assert DummyContext.is_descendant_of?(dummy_4, dummy_4) == false
      assert DummyContext.is_descendant_of?(dummy_4, dummy_2) == true
      assert DummyContext.is_descendant_of?(dummy_2, dummy_4) == false
      assert DummyContext.is_descendant_of?(dummy_4, dummy_1) == false
      assert DummyContext.is_descendant_of?(dummy_4, dummy_3) == false
    end

    test "is_or_is_descendant_of?", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]
      dummy_3 = context[:dummy_3]
      dummy_4 = context[:dummy_4]
      assert DummyContext.is_or_is_descendant_of?(dummy_4, dummy_4) == true
      assert DummyContext.is_or_is_descendant_of?(dummy_4, dummy_2) == true
      assert DummyContext.is_or_is_descendant_of?(dummy_2, dummy_4) == false
      assert DummyContext.is_or_is_descendant_of?(dummy_4, dummy_1) == false
      assert DummyContext.is_or_is_descendant_of?(dummy_4, dummy_3) == false
    end
  end

  describe "Queries" do
    setup do
      {:ok, dummy_1} = DummyContext.create_dummy(%{title: "first"})
      {:ok, dummy_2} = DummyContext.create_dummy(%{title: "second"})
      {:ok, dummy_3} = DummyContext.create_dummy(%{title: "third"})
      {:ok, dummy_4} = DummyContext.create_dummy(%{title: "fourth"}, dummy_2)
      {:ok, dummy_5} = DummyContext.create_dummy(%{title: "fourth"}, dummy_4)

      dummy_2 = DummyContext.get_dummy(dummy_2.id)
      dummy_3 = DummyContext.get_dummy(dummy_3.id)
      dummy_4 = DummyContext.get_dummy(dummy_4.id)

      {:ok, dummy_1: dummy_1, dummy_2: dummy_2, dummy_3: dummy_3, dummy_4: dummy_4, dummy_5: dummy_5}
    end

    test "root", context do
      assert DummyContext.root == context[:dummy_1]
    end

    test "root of", context do
      assert DummyContext.root(context[:dummy_4]) == context[:dummy_2]
      assert DummyContext.root(context[:dummy_5]) == context[:dummy_2]
      assert DummyContext.root(context[:dummy_1]) == context[:dummy_1]
    end

    test "roots", context do
      assert DummyContext.roots == [context[:dummy_1], context[:dummy_2], context[:dummy_3]]
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
      assert DummyContext.ancestors(dummy_1) == []
      assert DummyContext.ancestors(dummy_2) == []
      assert DummyContext.ancestors(dummy_3) == []
      assert DummyContext.ancestors(dummy_4) == [dummy_2]
      assert DummyContext.ancestors(dummy_5) == [dummy_2, dummy_4]
    end

    test "self and ancestors", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]
      dummy_3 = context[:dummy_3]
      dummy_4 = context[:dummy_4]
      dummy_5 = context[:dummy_5]
      assert DummyContext.self_and_ancestors(dummy_1) == [dummy_1]
      assert DummyContext.self_and_ancestors(dummy_2) == [dummy_2]
      assert DummyContext.self_and_ancestors(dummy_3) == [dummy_3]
      assert DummyContext.self_and_ancestors(dummy_4) == [dummy_2, dummy_4]

      # THIS TEST FAILS BECAUSE dummy_5 has preloaded data!
      # assert DummyContext.self_and_ancestors(context[:dummy_5]) == [context[:dummy_2], context[:dummy_4], context[:dummy_5]]

      # Test that it looks the same (without testing assoc)
      left = DummyContext.self_and_ancestors(dummy_5) |> sanitize()
      right = [dummy_2, dummy_4, dummy_5] |> sanitize()
      assert left == right
    end

    test "siblings", context do
      assert DummyContext.siblings(context[:dummy_4]) == []
      assert DummyContext.siblings(context[:dummy_5]) == []

      p1 = DummyContext.siblings(context[:dummy_1]) |> sanitize()
      p2 = DummyContext.siblings(context[:dummy_2]) |> sanitize()
      p3 = DummyContext.siblings(context[:dummy_3]) |> sanitize()

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
      assert DummyContext.self_and_siblings(dummy_4) == [dummy_4]
      assert DummyContext.self_and_siblings(dummy_5) |> sanitize() == [dummy_5] |> sanitize()

      p1 = DummyContext.self_and_siblings(dummy_1) |> sanitize()
      p2 = DummyContext.self_and_siblings(dummy_2) |> sanitize()
      p3 = DummyContext.self_and_siblings(dummy_3) |> sanitize()

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
      assert DummyContext.descendants(dummy_1) == []
      assert DummyContext.descendants(dummy_3) == []
      assert DummyContext.descendants(dummy_5) == []
      assert DummyContext.descendants(dummy_2) |> sanitize() == [dummy_4, dummy_5] |> sanitize()
      assert DummyContext.descendants(dummy_4) |> sanitize() == [dummy_5] |> sanitize()
    end

    test "self and descendants", context do
      dummy_1 = context[:dummy_1]
      dummy_2 = context[:dummy_2]
      dummy_3 = context[:dummy_3]
      dummy_4 = context[:dummy_4]
      dummy_5 = context[:dummy_5]
      assert DummyContext.self_and_descendants(dummy_1) == [dummy_1]
      assert DummyContext.self_and_descendants(dummy_3) == [dummy_3]
      assert DummyContext.self_and_descendants(dummy_5) |> sanitize() == [dummy_5] |> sanitize()
      assert DummyContext.self_and_descendants(dummy_2) |> sanitize() == [dummy_2, dummy_4, dummy_5] |> sanitize()
      assert DummyContext.self_and_descendants(dummy_4) |> sanitize() == [dummy_4, dummy_5] |> sanitize()
    end
  end

  # Private

  defp sanitize(collection) do
    collection |> Enum.map(fn p -> {p.id, p.lft, p.rgt, p.depth} end)
  end
end
