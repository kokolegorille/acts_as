defmodule ActsAs.NestedSet do
  @moduledoc """
  A behaviour module for implementing Acts as Nested set in Ecto.
  """

  @callback new_changeset(resource :: term, attrs :: term) :: %Ecto.Changeset{}
  @callback new_changeset(resource :: term, attrs :: term, parent_resource :: term) :: %Ecto.Changeset{}

  defmacro __using__(_opts) do
    quote do
      @behaviour ActsAs.NestedSet

      use ActsAs.NestedSet.Predicates
      use ActsAs.NestedSet.Queries
      use ActsAs.NestedSet.Multies

    end
  end
end
