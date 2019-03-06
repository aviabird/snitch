defmodule Snitch.Data.Schema.OptionValue do
  @moduledoc false

  use Snitch.Data.Schema
  alias Snitch.Data.Schema.{Option, Product}

  schema "snitch_option_values" do
    field(:value, :string)
    field(:value_data, :map)
    field(:display_name, :string)

    belongs_to(:option, Option)
    belongs_to(:product, Product)

    timestamps()
  end

  def changeset(model, params) do
    model
    |> cast(params, [:option_id, :product_id, :value])
    |> validate_required([:option_id, :value])
  end

  def update_changeset(model, params) do
    model
    |> cast(params, [:value])
    |> validate_required([:value])
  end
end
