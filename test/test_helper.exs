ExUnit.start()

alias Ecto.Integration.TestRepo

Application.put_env(
  :ecto,
  TestRepo,
  adapter: Ecto.Adapters.Postgres,
  url: System.get_env("DATABASE_URL", "ecto://localhost/ecto_network_test"),
  pool: Ecto.Adapters.SQL.Sandbox
)

defmodule Ecto.Integration.TestRepo do
  use Ecto.Repo,
    otp_app: :ecto,
    adapter: Ecto.Adapters.Postgres
end

{:ok, _} = Ecto.Adapters.Postgres.ensure_all_started(TestRepo, :temporary)

_ = Ecto.Adapters.Postgres.storage_down(TestRepo.config())
:ok = Ecto.Adapters.Postgres.storage_up(TestRepo.config())

{:ok, _pid} = TestRepo.start_link()

Code.require_file("ecto_migration.exs", __DIR__)

:ok = Ecto.Migrator.up(TestRepo, 0, Ecto.Integration.Migration, log: false)
Ecto.Adapters.SQL.Sandbox.mode(TestRepo, :manual)
Process.flag(:trap_exit, true)

# Define fake struct and context for tests

########################################
### DUMMY Nested Set
########################################

defmodule DummyNS do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ns_dummies" do
    # self join
    # IMPORTANT! on_replace: :nilify!!!
    # Otherwise it breaks move_to_root
    # https://github.com/elixir-ecto/ecto/issues/1432
    belongs_to(:parent, __MODULE__, foreign_key: :parent_id, on_replace: :nilify)
    has_many(:children, __MODULE__, foreign_key: :parent_id)
    has_many(:dummies, DummyList, foreign_key: :parent_id)

    # acts as nested set
    field :lft, :integer
    field :rgt, :integer
    field :depth, :integer
  end

  use ActsAs.NestedSet

  def changeset(%__MODULE__{} = dummy, attrs) do
    cast(dummy, attrs, [])
  end

  @impl ActsAs.NestedSet
  def new_changeset(%__MODULE__{} = dummy, attrs) do
    dummy
    |> changeset(attrs)
    |> generate_lft_rgt_depth()
  end

  @impl ActsAs.NestedSet
  def new_changeset(%__MODULE__{} = dummy, %__MODULE__{} = parent, attrs) do
    dummy
    |> changeset(attrs)
    |> generate_lft_rgt_depth(parent)
  end

  defp generate_lft_rgt_depth(%Ecto.Changeset{valid?: true} = changeset) do
    lft = get_max_rgt() + 1
    rgt = lft + 1
    depth = 0
    do_generate_lft_rgt_depth(changeset, lft, rgt, depth)
  end
  defp generate_lft_rgt_depth(%Ecto.Changeset{} = changeset), do: changeset

  defp generate_lft_rgt_depth(%Ecto.Changeset{valid?: true} = changeset, parent) do
    lft = parent.rgt
    rgt = lft + 1
    depth = parent.depth + 1
    do_generate_lft_rgt_depth(changeset, lft, rgt, depth)
  end
  defp generate_lft_rgt_depth(%Ecto.Changeset{} = changeset, _parent), do: changeset

  defp do_generate_lft_rgt_depth(
    %Ecto.Changeset{valid?: true} = changeset, lft, rgt, depth
  ) do
    changeset
    |> put_change(:depth, depth)
    |> put_change(:lft, lft)
    |> put_change(:rgt, rgt)
  end

  # In the real implementation, this is delegated to context
  # which knows about repo!
  defp get_max_rgt() do
    (DummyNS.max_rgt_query() |> TestRepo.one()) || 0
  end
end

########################################
### DUMMY Nested Set CONTEXT
########################################

defmodule DummyNSContext do
  import Ecto.Query, warn: false

  def list_dummies(), do: TestRepo.all(DummyNS)

  def get_dummy(id), do: TestRepo.get(DummyNS, id)

  def create_dummy(attrs) do
    %DummyNS{}
    |> DummyNS.insert(attrs)
    |> TestRepo.insert()
  end

  def create_dummy(attrs, parent) do
    parent
    |> Ecto.build_assoc(:children)
    |> DummyNS.insert(attrs, parent)
    |> TestRepo.transaction()
    |> case do
      {:ok, %{insert_resource: child}} ->
        {:ok, child}
      {:error, :insert_resource, changeset, _} ->
        {:error, changeset}
    end
  end

  def delete_dummy(%DummyNS{} = dummy) do
    {:ok, %{delete_resource: deleted}} = dummy
    |> DummyNS.delete()
    |> TestRepo.transaction()

    {:ok, deleted}
  end

  ### DummyNS Predicates

  defdelegate root?(dummy), to: DummyNS
  defdelegate child?(dummy), to: DummyNS
  defdelegate leaf?(dummy), to: DummyNS
  defdelegate is_ancestor_of?(object, subject), to: DummyNS
  defdelegate is_or_is_ancestor_of?(object, subject), to: DummyNS
  defdelegate is_descendant_of?(object, subject), to: DummyNS
  defdelegate is_or_is_descendant_of?(object, subject), to: DummyNS

  ### PAGE QUERIES

  def root, do: DummyNS.root |> TestRepo.one
  def root(%DummyNS{} = dummy), do: DummyNS.root(dummy) |> TestRepo.one

  def roots, do: DummyNS.roots() |> TestRepo.all

  def leaves, do: DummyNS.leaves |> TestRepo.all

  def ancestors(%DummyNS{} = dummy), do: DummyNS.ancestors(dummy) |> TestRepo.all

  def self_and_ancestors(%DummyNS{} = dummy),
    do: DummyNS.self_and_ancestors(dummy) |> TestRepo.all

  def siblings(%DummyNS{} = dummy), do: DummyNS.siblings(dummy) |> TestRepo.all

  def self_and_siblings(%DummyNS{} = dummy),
    do: DummyNS.self_and_siblings(dummy) |> TestRepo.all

  def descendants(%DummyNS{} = dummy), do: DummyNS.descendants(dummy) |> TestRepo.all

  def self_and_descendants(%DummyNS{} = dummy),
    do: DummyNS.self_and_descendants(dummy) |> TestRepo.all

  ### DummyNS Movements

  def move_to_child_of(%DummyNS{} = dummy, parent) when is_nil(parent), do: move_to_root(dummy)
  def move_to_child_of(%DummyNS{} = dummy, %DummyNS{} = parent) do
    dummy = ensure_preload(dummy, :parent)

    case DummyNS.move_to_child_of(dummy, parent) do
      {:error, reason} -> {:error, reason}
      %Ecto.Multi{} = multi -> TestRepo.transaction(multi)
    end
  end

  def move_to_root(%DummyNS{depth: 0}), do: {:error, "already at root level"}
  def move_to_root(%DummyNS{} = dummy) do
    move_to_right_of(dummy, last_root())
  end

  def move_to_left_of(%DummyNS{} = dummy, %DummyNS{} = brother) do
    dummy = dummy
    |> ensure_preload(:parent)

    brother = brother
    |> ensure_preload(:parent)

    case DummyNS.move_to_left_of(dummy, brother) do
      {:error, reason} -> {:error, reason}
      %Ecto.Multi{} = multi -> TestRepo.transaction(multi)
    end
  end

  def move_to_right_of(%DummyNS{} = dummy, %DummyNS{} = brother) do
    dummy = dummy
    |> ensure_preload(:parent)

    brother = brother
    |> ensure_preload(:parent)

    case DummyNS.move_to_right_of(dummy, brother) do
      {:error, reason} -> {:error, reason}
      %Ecto.Multi{} = multi -> TestRepo.transaction(multi)
    end
  end

  defp last_root() do
    DummyNS.roots()
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
### DUMMY List
########################################

defmodule DummyList do
  use Ecto.Schema
  import Ecto.Changeset

  schema "l_dummies" do
    # parent join
    belongs_to(:parent, DummyNS, foreign_key: :parent_id, on_replace: :nilify)

    # acts as list
    field :position, :integer
  end

  use ActsAs.List, scope: :parent_id

  def changeset(%__MODULE__{} = dummy, attrs) do
    cast(dummy, attrs, [])
  end

  @impl ActsAs.List
  def new_changeset(%__MODULE__{} = dummy, attrs) do
    dummy
    |> changeset(attrs)
    |> generate_position()
  end

  defp generate_position(%Ecto.Changeset{valid?: true, data: %{parent_id: parent_id}} = changeset) do
    position = get_max_position(parent_id) + 1
    put_change(changeset, :position, position)
  end

  defp generate_position(changeset), do: changeset

  # In the real implementation, this is delegated to context
  # which knows about repo!
  def get_max_position() do
    (DummyList.max_position_query() |> TestRepo.one()) || 0
  end

  def get_max_position(scope_value) do
    (DummyList.max_position_query(scope_value) |> TestRepo.one()) || 0
  end
end

########################################
### DUMMY List CONTEXT
########################################

defmodule DummyListContext do
  import Ecto.Query, warn: false

  def list_dummies(), do: TestRepo.all(DummyList)

  def get_dummy(id), do: TestRepo.get(DummyList, id)

  def create_dummy(attrs) do
    %DummyList{}
    |> DummyList.insert(attrs)
    |> TestRepo.insert()
  end

  def create_dummy(attrs, parent) do
    parent
    |> Ecto.build_assoc(:dummies)
    |> DummyList.insert(attrs)
    |> TestRepo.insert()
  end

  def delete_dummy(%DummyList{} = dummy) do
    {:ok, %{delete_resource: deleted}} = dummy
    |> DummyList.delete()
    |> TestRepo.transaction()

    {:ok, deleted}
  end
end
