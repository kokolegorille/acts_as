defmodule ActsAs.List.Predicates do
  @moduledoc """
  The predicates module
  """
  defmacro __using__(_opts) do
    quote do
      def first?(%__MODULE__{position: position} = _resource), do: position == 1

      # last?
      # in_list?
      # not_in_list?
      # default_position?
      # higher_item
      # higher_items
      # lower_item
      # lower_items

    end
  end
end
