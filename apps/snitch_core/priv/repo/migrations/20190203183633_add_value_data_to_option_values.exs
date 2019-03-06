defmodule Snitch.Repo.Migrations.AddValueDataToOptionValues do
  use Ecto.Migration

  def change do
    alter table(:snitch_option_values) do
      add :value_data, :map
    end
  end
end
