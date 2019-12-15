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
### DUMMY
########################################

defmodule Dummy do
  use Ecto.Schema
  import Ecto.Changeset

  schema "dummies" do
    # self join
    # IMPORTANT! on_replace: :nilify!!!
    # Otherwise it breaks move_to_root
    # https://github.com/elixir-ecto/ecto/issues/1432
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
  def new_changeset(%__MODULE__{} = dummy, %__MODULE__{} = parent, attrs) do
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
    dummy = ensure_preload(dummy, :parent)

    case Dummy.move_to_child_of(dummy, parent) do
      {:error, reason} -> {:error, reason}
      %Ecto.Multi{} = multi -> TestRepo.transaction(multi)
    end
  end

  def move_to_root(%Dummy{depth: 0}), do: {:error, "already at root level"}
  def move_to_root(%Dummy{} = dummy) do
    move_to_right_of(dummy, last_root())
  end

  def move_to_left_of(%Dummy{} = dummy, %Dummy{} = brother) do
    dummy = dummy
    |> ensure_preload(:parent)

    brother = brother
    |> ensure_preload(:parent)

    case Dummy.move_to_left_of(dummy, brother) do
      {:error, reason} -> {:error, reason}
      %Ecto.Multi{} = multi -> TestRepo.transaction(multi)
    end
  end

  def move_to_right_of(%Dummy{} = dummy, %Dummy{} = brother) do
    dummy = dummy
    |> ensure_preload(:parent)

    brother = brother
    |> ensure_preload(:parent)

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
