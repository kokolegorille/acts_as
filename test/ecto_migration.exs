defmodule Ecto.Integration.Migration do
  use Ecto.Migration

  def change do
    create table(:ns_dummies) do
      # self join
      add :parent_id, references(:ns_dummies, on_delete: :delete_all)
      # acts as nested set
      add :lft, :integer
      add :rgt, :integer
      add :depth, :integer, null: false, default: 0
    end

    create table(:l_dummies) do
      # parent join
      add :parent_id, references(:ns_dummies, on_delete: :delete_all)
      # acts as list
      add :position, :integer
    end
  end
end
