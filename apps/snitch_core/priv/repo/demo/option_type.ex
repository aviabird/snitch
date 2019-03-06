defmodule Snitch.Demo.OptionType do
  alias NimbleCSV.RFC4180, as: CSV
  alias Snitch.Core.Tools.MultiTenancy.Repo
  alias Snitch.Data.Schema.Option

  @base_path Application.app_dir(:snitch_core, "priv/repo/demo/demo_data")

  def create_option_types do
    Repo.delete_all(Option)
    options_path = Path.join(@base_path, "options.csv")

    options_path
    |> File.read!()
    |> CSV.parse_string()
    |> Enum.each(fn [name, display_name] ->
      create_option_type!(name, display_name)
    end)
  end

  def create_option_type!(name, display_name) do
    params = %{
      name: name,
      display_name: display_name
    }

    %Option{} |> Option.create_changeset(params) |> Repo.insert!()
  end
end
