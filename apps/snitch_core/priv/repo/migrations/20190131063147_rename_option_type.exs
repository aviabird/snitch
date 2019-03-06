defmodule Snitch.Repo.Migrations.RenameOptionType do
  use Ecto.Migration

  def change do
    drop unique_index("snitch_option_types", [:name])

    rename table(:snitch_option_types), to: table(:snitch_options)

    create unique_index("snitch_options", [:name])

    execute "ALTER TABLE snitch_template_option_values DROP CONSTRAINT snitch_template_option_values_option_type_id_fkey"
    rename table(:snitch_template_option_values), :option_type_id, to: :option_id
    alter table(:snitch_template_option_values) do
      modify :option_id, references("snitch_options", on_delete: :delete_all), null: false
    end

    execute "ALTER TABLE snitch_theme_option_types DROP CONSTRAINT snitch_theme_option_types_option_type_id_fkey"
    rename table(:snitch_theme_option_types), :option_type_id, to: :option_id
    alter table(:snitch_theme_option_types) do
      modify :option_id, references("snitch_options", on_delete: :delete_all), null: false
    end

    execute "ALTER TABLE snitch_product_option_values DROP CONSTRAINT snitch_product_option_values_option_type_id_fkey"
    rename table(:snitch_product_option_values), :option_type_id, to: :option_id
    alter table(:snitch_product_option_values) do
      modify :option_id, references("snitch_options", on_delete: :delete_all), null: false
    end
  end
end
