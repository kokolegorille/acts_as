defmodule ActsAs.NestedSet.Predicates do
  defmacro __using__(_opts) do
    quote do
      def root?(%__MODULE__{parent_id: parent_id} = _resource), do: is_nil(parent_id)

      def child?(%__MODULE__{} = resource), do: !root?(resource)

      def is_ancestor_of?(
        %__MODULE__{lft: lft, rgt: rgt, id: id} = _object,
        %__MODULE__{lft: p_lft, rgt: p_rgt, id: p_id} = _subject
      ), do: lft <= p_lft && rgt >= p_rgt && id != p_id

      def is_or_is_ancestor_of?(
        %__MODULE__{lft: lft, rgt: rgt} = _object,
        %__MODULE__{lft: p_lft, rgt: p_rgt} = _subject
      ), do: lft <= p_lft && rgt >= p_rgt

      def is_descendant_of?(
        %__MODULE__{lft: lft, id: id} = _object,
        %__MODULE__{lft: p_lft, rgt: p_rgt, id: p_id} = _subject
      ), do: lft >= p_lft && lft < p_rgt && id != p_id

      def is_or_is_descendant_of?(
        %__MODULE__{lft: lft} = _object,
        %__MODULE__{lft: p_lft, rgt: p_rgt} = _subject
      ), do: lft >= p_lft && lft < p_rgt

      def leaf?(%__MODULE__{lft: lft, rgt: rgt} = _resource), do: rgt - lft == 1
    end
  end
end
