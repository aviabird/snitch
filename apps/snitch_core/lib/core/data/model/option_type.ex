defmodule Snitch.Data.Model.Option do
  @moduledoc """
  Option API
  """
  use Snitch.Data.Model
  alias Snitch.Data.Schema.Option
  alias Snitch.Data.Schema.Product
  alias Snitch.Core.Tools.MultiTenancy.Repo
  import Ecto.Query

  @doc """
  Create a Option with supplied params
  """
  @spec create(map) :: {:ok, Option.t()} | {:error, Ecto.Changeset.t()}
  def create(params) do
    QH.create(Option, params, Repo)
  end

  @doc """
  Returns all Options
  """
  @spec get_all() :: [Option.t()]
  def get_all do
    Repo.all(Option)
  end

  @doc """
  Returns an Option

  Takes OptionType id as input
  """
  @spec get(integer) :: {:ok, Option.t()} | {:error, atom}
  def get(id) do
    QH.get(Option, id, Repo)
  end

  @doc """
  Update the Option with supplied params and Option instance
  """
  @spec update(Option.t(), map) :: {:ok, Option.t()} | {:error, Ecto.Changeset.t()}
  def update(model, params) do
    QH.update(Option, params, model, Repo)
  end

  @doc """
  Deletes the Option
  """
  @spec delete(non_neg_integer | struct()) ::
          {:ok, Option.t()} | {:error, Ecto.Changeset.t()} | {:error, :not_found}
  def delete(id) when is_integer(id) do
    QH.delete(Option, id, Repo)
  end

  def delete(%Option{} = instance) do
    QH.delete(Option, instance, Repo)
  end

  @doc """
  Checks whether the Option is associated to any product's variation theme.
  """
  @spec is_theme_associated(non_neg_integer) :: true | false
  def is_theme_associated(option_type_id) do
    option_preloader = from(ot in Option, where: ot.id == ^option_type_id)

    products =
      from(p in Product, preload: [theme: [option_types: ^option_preloader]]) |> Repo.all()

    Enum.any?(products, fn product ->
      if product.theme != nil, do: length(product.theme.option_types) > 0
    end)
  end
end
