defmodule Snitch.Data.Schema.VariationTheme do
  @moduledoc """
  Models Variation theme

  Variation theme is group of Options
  """

  use Snitch.Data.Schema
  import Ecto.Query

  alias Snitch.Data.Schema.Option

  @type t :: %__MODULE__{}

  schema "snitch_variation_theme" do
    field(:name, :string)
    field(:option_type_ids, {:array, :binary}, virtual: true)

    many_to_many(
      :option_types,
      Option,
      join_through: "snitch_theme_option_types",
      join_keys: [variation_theme_id: :id, option_id: :id],
      on_replace: :delete
    )

    timestamps()
  end

  @create_params ~w(name option_type_ids)a

  @doc """
  Returns a changeset to create new Variation theme
  """
  def create_changeset(model, params) do
    common_changeset(model, params)
  end

  @doc """
  Returns a changeset to update a Variation theme
  """
  def update_changeset(model, params) do
    common_changeset(model, params)
  end

  defp common_changeset(model, params) do
    model
    |> Repo.preload(:option_types)
    |> cast(params, @create_params)
    |> validate_required(@create_params)
    |> unique_constraint(:name)
    |> put_assoc_option_types(params["option_type_ids"])
  end

  defp put_assoc_option_types(changeset, option_type) when option_type == nil do
    option_type_ids = Enum.map(changeset.data.option_types, & &1.id)

    changeset
    |> put_change(:option_type_ids, option_type_ids)
    |> put_assoc(:option_types, Enum.map([], &change/1))
  end

  defp put_assoc_option_types(changeset, option_type) when option_type == "" do
    changeset
  end

  defp put_assoc_option_types(changeset, option_types) do
    option_types = Repo.all(from(cr in Option, where: cr.id in ^option_types))

    put_assoc(changeset, :option_types, Enum.map(option_types, &change/1))
  end
end
