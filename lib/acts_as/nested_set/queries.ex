defmodule ActsAs.NestedSet.Queries do
  @moduledoc """
  The queries module
  """
  defmacro __using__(_opts) do
    quote do
      import Ecto.Query, warn: false

      def root, do: from(i in __MODULE__, order_by: :lft, limit: 1)
      def root(%__MODULE__{lft: lft, rgt: rgt} = _resource) do
        from(r in __MODULE__,
          where: r.lft <= ^lft,
          where: r.rgt >= ^rgt,
          where: is_nil(r.parent_id),
          order_by: :lft
        )
      end

      def roots, do: from(r in __MODULE__, where: is_nil(r.parent_id), order_by: :lft)

      # For compatibility purpose!
      def level(%__MODULE__{depth: depth} = _resource), do: depth

      def ancestors(%__MODULE__{lft: lft, rgt: rgt, id: id} = _resource) do
        from(r in __MODULE__,
          where: r.lft <= ^lft,
          where: r.rgt >= ^rgt,
          where: r.id != ^id,
          order_by: :lft
        )
      end

      def self_and_ancestors(%__MODULE__{lft: lft, rgt: rgt} = _resource) do
        from(r in __MODULE__,
          where: r.lft <= ^lft,
          where: r.rgt >= ^rgt,
          order_by: :lft
        )
      end

      def siblings(%__MODULE__{parent_id: parent_id, id: id} = _page) when is_nil(parent_id) do
        from(r in __MODULE__,
          where: is_nil(r.parent_id),
          where: r.id != ^id,
          order_by: :lft
        )
      end
      def siblings(%__MODULE__{parent_id: parent_id, id: id} = _resource) do
        from(r in __MODULE__,
          where: r.parent_id == ^parent_id,
          where: r.id != ^id,
          order_by: :lft
        )
      end

      def self_and_siblings(%__MODULE__{parent_id: parent_id} = _resource) when is_nil(parent_id) do
        from(r in __MODULE__,
          where: is_nil(r.parent_id),
          order_by: :lft
        )
      end
      def self_and_siblings(%__MODULE__{parent_id: parent_id} = _resource) do
        from(r in __MODULE__,
          where: r.parent_id == ^parent_id,
          order_by: :lft
        )
      end

      def descendants(%__MODULE__{lft: lft, rgt: rgt, id: id} = _resource) do
        from(r in __MODULE__,
          where: r.lft >= ^lft,
          where: r.lft < ^rgt,
          where: r.id != ^id,
          order_by: :lft
        )
      end

      def self_and_descendants(%__MODULE__{lft: lft, rgt: rgt} = _resource) do
        from(r in __MODULE__,
          where: r.lft >= ^lft,
          where: r.lft < ^rgt,
          order_by: :lft
        )
      end

      def leaves, do: from(r in __MODULE__, where: fragment("? + 1", r.lft) == r.rgt, order_by: :lft)

      def max_rgt, do: from(r in __MODULE__, select: max(r.rgt))
    end
  end
end
