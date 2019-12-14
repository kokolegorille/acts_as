defmodule ActsAs.List do
  @moduledoc """
  A behaviour module for implementing Acts as List in Ecto.
  """

  @callback new_changeset(resource :: term, attrs :: term) :: %Ecto.Changeset{}

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour ActsAs.List

      use ActsAs.List.Queries, opts
      use ActsAs.List.Multies
    end
  end
end
