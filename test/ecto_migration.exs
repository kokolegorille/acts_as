defmodule Ecto.Integration.Migration do
  use Ecto.Migration

  def change do
    create table(:dummies) do
      # self join
      add :parent_id, references(:dummies, on_delete: :delete_all)
      # nested set
      add :lft, :integer
      add :rgt, :integer
      add :depth, :integer, null: false, default: 0
    end
  end
end
