defmodule ActsAs.NestedSet do
  @moduledoc ~S"""
  A behaviour module for implementing Acts as Nested set in Ecto.
  ActsAs.NestedSet is split into 3 main components:

    * `ActsAs.NestedSet.Multies` - Ecto.Multi queries to insert and delete elements

    * `ActsAs.NestedSet.Predicates` - Boolean functions comparing elements

    * `ActsAs.NestedSet.Queries` - Ecto queries to retrieve elements
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
