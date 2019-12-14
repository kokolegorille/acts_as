defmodule ActsAs.NestedSet.Multies do
  @moduledoc """
  The multies module
  """
  defmacro __using__(_opts) do
    quote do
      import ActsAs.NestedSet.Multies
      import Ecto.Query, warn: false
      alias Ecto.Multi

      def insert(%__MODULE__{} = resource, attrs) do
        new_changeset(resource, attrs)
      end
      def insert(%__MODULE__{} = resource, attrs, parent) when is_nil(parent),
        do: insert(resource, attrs)
      def insert(%__MODULE__{} = resource, attrs, %__MODULE__{rgt: rgt} = parent) do
        new_resource = resource
        |> child_changeset(parent, attrs)
        |> put_assoc(:parent, parent)

        update_rgt_query = from(i in __MODULE__, where: i.rgt >= ^rgt, update: [inc: [rgt: 2]])
        update_lft_query = from(i in __MODULE__, where: i.lft > ^rgt, update: [inc: [lft: 2]])

        Multi.new()
        |> Multi.update_all(:update_rgt, update_rgt_query, [])
        |> Multi.update_all(:update_lft, update_lft_query, [])
        |> Multi.insert(:insert_resource, new_resource)
      end

      # YOU NEED TO PASS A RESOURCE UP TO DATE WITH PRELOADED DATA!
      def delete(%__MODULE__{lft: lft, rgt: rgt} = resource) do
        width = rgt - lft + 1
        update_rgt_query = from(i in __MODULE__, where: i.rgt > ^rgt, update: [inc: [rgt:  ^(-width)]])
        update_lft_query = from(i in __MODULE__, where: i.lft > ^rgt, update: [inc: [lft: ^(-width)]])

        Multi.new
        |> Multi.delete(:delete_resource, resource)
        |> Multi.update_all(:update_rgt, update_rgt_query, [])
        |> Multi.update_all(:update_lft, update_lft_query, [])
      end

      def move_to_child_of(
        %__MODULE__{lft: lft, rgt: rgt, depth: depth} = resource,
        %__MODULE__{lft: p_lft, rgt: p_rgt, depth: p_depth} = parent)
      do
        case is_or_is_ancestor_of?(resource, parent) do
          true -> {:error, "cannot be moved to child of child or self!"}
          _ ->
            width = rgt - lft + 1
            depth_diff = p_depth - depth + 1

            # Update depth
            update_depth_query = from(i in __MODULE__, where: i.lft >= ^lft and i.rgt <= ^rgt, update: [inc: [depth: ^depth_diff]])

            # update parent for resource
            updated_resource = resource |> change() |> put_assoc(:parent, parent)

            [
              {inside_lft, inside_rgt, inside_inc},
              {outside_lft, outside_rgt, outside_inc}
            ] = if lft > p_rgt do
              # From right to left
              diff = p_rgt - lft
              [{lft, rgt, diff}, {p_rgt, lft - 1, width}]
            else
              # From left to right
              diff = p_lft - rgt
              [{lft, rgt, diff}, {lft + 1, p_lft, -width}]
            end

            # Update lft and rgt from fragments
            update_lft_rgt_query = from(i in __MODULE__,
              update: [
                set: [
                  lft: left_fragment(^inside_lft, ^inside_rgt, ^inside_inc, ^outside_lft, ^outside_rgt, ^outside_inc),
                  rgt: right_fragment(^inside_lft, ^inside_rgt, ^inside_inc, ^outside_lft, ^outside_rgt, ^outside_inc)
                ]
              ]
            )

            Multi.new
            |> Multi.update(:update_parent, updated_resource)
            |> Multi.update_all(:update_depth, update_depth_query, [])
            |> Multi.update_all(:update_lft_rgt, update_lft_rgt_query, [])
        end
      end

      def move_to_right_of(
        %__MODULE__{lft: lft, rgt: rgt, depth: depth} = resource,
        %__MODULE__{rgt: b_rgt, depth: b_depth} = brother) do

        case is_or_is_ancestor_of?(resource, brother) do
          true -> {:error, "cannot be moved to right of child or self!"}
          _ ->
            width = rgt - lft + 1
            depth_diff = b_depth - depth
            parent = brother.parent
            # |> IO.inspect(label: "PARENT")

            updated_resource = resource |> change() |> put_assoc(:parent, parent)

            # Update depth
            update_depth_query = from(i in __MODULE__, where: i.lft >= ^lft and i.rgt <= ^rgt, update: [inc: [depth: ^depth_diff]])

            [{inside_lft, inside_rgt, inside_inc}, {outside_lft, outside_rgt, outside_inc}] = if lft > b_rgt do
              # From right to left
              diff = b_rgt + 1 - lft
              [{lft, rgt, diff}, {b_rgt + 1, lft - 1, width}]
            else
              # From left to right
              diff = b_rgt - rgt
              [{lft, rgt, diff}, {rgt + 1, b_rgt, -width}]
            end

            # Update lft and rgt from fragments
            update_lft_rgt_query = from(i in __MODULE__,
              update: [
                set: [
                  lft: left_fragment(^inside_lft, ^inside_rgt, ^inside_inc, ^outside_lft, ^outside_rgt, ^outside_inc),
                  rgt: right_fragment(^inside_lft, ^inside_rgt, ^inside_inc, ^outside_lft, ^outside_rgt, ^outside_inc)
                ]
              ]
            )

            Multi.new
            |> Multi.update_all(:update_depth, update_depth_query, [])
            |> Multi.update_all(:update_lft_rgt, update_lft_rgt_query, [])
            |> Multi.update(:update_parent, updated_resource)
        end
      end

      def move_to_left_of(
        %__MODULE__{lft: lft, rgt: rgt, depth: depth} = resource,
        %__MODULE__{lft: b_lft, depth: b_depth} = brother) do

        case is_or_is_ancestor_of?(resource, brother) do
          true -> {:error, "cannot be moved to left of child or self!"}
          _ ->
            width = rgt - lft + 1
            depth_diff = b_depth - depth

            # Update depth
            update_depth_query = from(i in __MODULE__, where: i.lft >= ^lft and i.rgt <= ^rgt, update: [inc: [depth: ^depth_diff]])

            # update parent for resource
            updated_resource = resource |> change() |> put_assoc(:parent, brother.parent)

            [{inside_lft, inside_rgt, inside_inc}, {outside_lft, outside_rgt, outside_inc}] = if lft > b_lft do
              # From right to left
              diff = b_lft - lft
              [{lft, rgt, diff}, {b_lft, lft - 1, width}]
            else
              # From left to right
              diff = b_lft - 1 - rgt
              [{lft, rgt, diff}, {rgt + 1, b_lft - 1, -width}]
            end

            # Update lft and rgt from fragments
            update_lft_rgt_query = from(i in __MODULE__,
              update: [
                set: [
                  lft: left_fragment(^inside_lft, ^inside_rgt, ^inside_inc, ^outside_lft, ^outside_rgt, ^outside_inc),
                  rgt: right_fragment(^inside_lft, ^inside_rgt, ^inside_inc, ^outside_lft, ^outside_rgt, ^outside_inc)
                ]
              ]
            )

            Multi.new
            |> Multi.update_all(:update_depth, update_depth_query, [])
            |> Multi.update_all(:update_lft_rgt, update_lft_rgt_query, [])
            |> Multi.update(:update_parent, updated_resource)
        end
      end
    end
  end

  ########################################
  #
  # MACROS
  #
  ########################################

  # Updating the tree requires to modify lft and rgt for...
  #
  # * The moving node and children, (INSIDE)
  # * The zone in between movement  (OUTSIDE)
  #
  # For each You need to determine the size of increment (can be negative!)
  #
  # Moving node use the size of the movement, which is tricky to determine!
  # In between zone use the width of the moving node

  defmacro left_fragment(inside_lft, inside_rgt, inside_increment, outside_lft, outside_rgt, outside_increment) do
    quote do
      fragment(
        "CASE WHEN lft BETWEEN ? AND ? THEN lft + ? WHEN lft BETWEEN ? AND ? THEN lft + ? ELSE lft END",
        unquote(inside_lft), unquote(inside_rgt), unquote(inside_increment),
        unquote(outside_lft), unquote(outside_rgt), unquote(outside_increment)
      )
    end
  end

  defmacro right_fragment(inside_lft, inside_rgt, inside_increment, outside_lft, outside_rgt, outside_increment) do
    quote do
      fragment(
        "CASE WHEN rgt BETWEEN ? AND ? THEN rgt + ? WHEN rgt BETWEEN ? AND ? THEN rgt + ? ELSE rgt END",
        unquote(inside_lft), unquote(inside_rgt), unquote(inside_increment),
        unquote(outside_lft), unquote(outside_rgt), unquote(outside_increment)
      )
    end
  end
end
