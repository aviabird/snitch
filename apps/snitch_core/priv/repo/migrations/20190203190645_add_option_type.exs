defmodule Snitch.Repo.Migrations.AddOptionType do
  use Ecto.Migration

  def change do
    create table(:snitch_option_types) do
      add :display_name, :string
      add :config, :map
      add :type, OptionTypeEnum.type(), null: false
      timestamps()
    end
  end
end
