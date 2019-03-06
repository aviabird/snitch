defmodule Snitch.Demo.VariationTheme do
  alias Snitch.Core.Tools.MultiTenancy.Repo
  alias Snitch.Data.Schema.VariationTheme
  alias Snitch.Data.Schema.Option

  defp get_option_type do
    Repo.all(Option)
  end

  def create_variation_themes do
    Repo.delete_all(VariationTheme)
    option_types = get_option_type

    for i <- 1..length(option_types),
        do: option_types |> Combination.combine(i) |> create_variations
  end

  def create_variations(option_combination) do
    for options <- option_combination, do: create_variation(options)
  end

  def create_variation(options) do
    option_ids = for option <- options, do: to_string(option.id)
    option_names = for option <- options, do: option.name
    create_variation_theme(Enum.join(option_names, "-"), option_ids)
  end

  def create_variation_theme(name, option_type_ids) do
    params = %{
      "name" => name,
      "option_type_ids" => option_type_ids
    }

    %VariationTheme{} |> VariationTheme.create_changeset(params) |> Repo.insert!()
  end
end
