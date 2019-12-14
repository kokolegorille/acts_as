defmodule ActsAs.List.Multies do
  defmacro __using__(_opts) do
    quote do
      def insert(%__MODULE__{} = resource, attrs) do
        new_changeset(resource, attrs)
      end

      def delete(%__MODULE__{position: position} = resource) do

      end
    end
  end
end
