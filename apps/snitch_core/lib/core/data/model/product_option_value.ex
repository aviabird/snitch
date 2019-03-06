defmodule Snitch.Data.Model.OptionValue do
  @moduledoc """
  Option Value API.
  """

  use Snitch.Data.Model

  alias Snitch.Data.Schema.OptionValue

  @doc """
  Update the Option Value with supplied params and Option Value instance
  """
  @spec update(OptionValue.t(), map) :: {:ok, OptionValue.t()} | {:error, Ecto.Changeset.t()}
  def update(model, params) do
    QH.update(OptionValue, params, model, Repo)
  end

  @doc """
  Returns an Option Value

  Takes Product Option Value id as input
  """
  @spec get(integer) :: {:ok, OptionValue.t()} | {:error, atom}
  def get(id) do
    QH.get(OptionValue, id, Repo)
  end
end
