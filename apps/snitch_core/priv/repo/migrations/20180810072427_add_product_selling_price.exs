defmodule Snitch.Repo.Migrations.AddProductSellingPrice do
  use Ecto.Migration

  def change do
    alter table("snitch_products") do
      add :selling_price, :money_with_currency, null: false
      add :max_retail_price, :money_with_currency, null: false
    end
  end
end
