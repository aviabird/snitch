defmodule Snitch.Seed.OptionType do
  alias Snitch.Core.Tools.MultiTenancy.Repo
  alias Snitch.Data.Schema.Option

  def seed!() do
    create_option_type("size", "Size")
    create_option_type("color", "Color")
  end

  def create_option_type(name, display_name) do
    params = %{
      name: name,
      display_name: display_name
    }

    %Option{} |> Option.create_changeset(params) |> Repo.insert!()
  end
end
