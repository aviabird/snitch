defmodule Snitch.Data.Schema.OptionType do
  use Snitch.Data.Schema

  @type t :: %__MODULE__{}

  schema "snitch_option_types" do
    field(:display_name, :string)
    field(:config, :map)
    field(:type, OptionTypeEnum, default: :rectangle)
    timestamps()
  end
end
