defmodule ActsAs.List.Multies do
  @moduledoc """
  The multies module
  """
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import ActsAs.List.Multies
      import Ecto.Query, warn: false
      import Ecto.Changeset
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

      # Without scope
      def move_from_to(
        %__MODULE__{id: from_id} = from, %__MODULE__{id: to_id} = to
      ) when from_id == to_id do
        {:error, "cannot be moved to itself"}
      end

      def move_from_to(
        %__MODULE__{id: from_id, position: from_position} = from,
        %__MODULE__{position: to_position} = to
      ) do
        update_rest_query = if from_position > to_position do
          from(i in __MODULE__,
            where: i.position >= ^to_position and
              i.position < ^from_position,
            update: [inc: [position: + 1]]
          )
        else
          from(i in __MODULE__,
            where: i.position <= ^to_position and
              i.position > ^from_position,
            update: [inc: [position: - 1]]
          )
        end

        update_from_query =
          from(i in __MODULE__,
            where: i.id == ^from_id,
            update: [set: [position: ^to_position]]
          )

        Multi.new
        |> Multi.update_all(:update_rest, update_rest_query, [])
        |> Multi.update_all(:update_from, update_from_query, [])
      end

      # With scope
      def move_from_to(
        %__MODULE__{id: from_id} = from, %__MODULE__{id: to_id} = to, _scope_value
      ) when from_id == to_id do
        {:error, "cannot be moved to itself"}
      end
      def move_from_to(
        %__MODULE__{id: from_id, position: from_position} = from,
        %__MODULE__{position: to_position} = to,
        scope_value
      ) do
        opts = unquote(opts)
        scope = Keyword.get(opts, :scope)

        update_rest_query = if from_position > to_position do
          from(i in __MODULE__,
            where: i.position >= ^to_position and
              i.position < ^from_position and
              field(i, ^scope) == ^scope_value,
            update: [inc: [position: + 1]]
          )
        else
          from(i in __MODULE__,
            where: i.position <= ^to_position and
              i.position > ^from_position and
              field(i, ^scope) == ^scope_value,
            update: [inc: [position: - 1]]
          )
        end

        # Update from as a single resource
        # This allows to use Multi.update, instead of update_all
        update_resource = from
        |> change()
        |> put_change(:position, to_position)

        Multi.new
        |> Multi.update_all(:update_rest, update_rest_query, [])
        |> Multi.update(:update_from, update_resource, [])
      end

      # insert_at
      # move_lower
      # move_higher
      # move_to_top
      # move_to_bottom

    end
  end
end
