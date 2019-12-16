defmodule ActsAs.List.Multies do
  @moduledoc """
  The multies module
  """
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import ActsAs.List.Multies
      import Ecto.Query, warn: false
      alias Ecto.Multi

      def insert(%__MODULE__{} = resource, attrs) do
        new_changeset(resource, attrs)
      end

      def delete(%__MODULE__{position: position} = resource) do
        opts = unquote(opts)
        scope = Keyword.get(opts, :scope)

        update_position_query = if scope do
          from(i in __MODULE__,
            where: i.position > ^position and field(i, ^scope) == ^(Map.get(resource, scope)),
            update: [inc: [position: -1]]
          )
        else
          from(i in __MODULE__, where: i.position > ^position, update: [inc: [position: -1]])
        end

        Multi.new
        |> Multi.delete(:delete_resource, resource)
        |> Multi.update_all(:update_position, update_position_query, [])
      end

      # insert_at
      # move_lower
      # move_higher
      # move_to_top
      # move_to_bottom

    end
  end
end
