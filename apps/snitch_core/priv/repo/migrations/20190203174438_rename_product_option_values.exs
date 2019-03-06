defmodule Snitch.Repo.Migrations.RenameProductOptionValues do
  use Ecto.Migration

  def change do
    rename table(:snitch_product_option_values), to: table(:snitch_option_values)
  end
end
