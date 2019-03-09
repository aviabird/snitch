defmodule Snitch.Repo.Migrations.AlterPromoAdjustmentsCascadeDelete do
  use Ecto.Migration

  def change do
    execute "ALTER TABLE snitch_promotion_adjustments DROP CONSTRAINT snitch_promotion_adjustments_adjustment_id_fkey"
    alter table("snitch_promotion_adjustments") do
      modify(:adjustment_id, references("snitch_adjustments", on_delete: :delete_all))
    end
  end
end
