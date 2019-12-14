defmodule ActsAs.List.Queries do
  @moduledoc """
  The queries module
  """
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import Ecto.Query, warn: false

      def max_position() do
        from(r in __MODULE__, select: max(r.position))
      end

      def max_position(scope_value) do
        opts = unquote(opts)
        scope = Keyword.fetch!(opts, :scope)

        # Use field for dynamic query
        from(r in __MODULE__, where: field(r, ^scope) == ^scope_value, select: max(r.position))
      end

    end
  end
end
