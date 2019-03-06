defmodule SnitchApiWeb.ProductOptionValueController do
  use SnitchApiWeb, :controller

  alias Snitch.Data.Model.OptionValue

  def update(conn, %{"id" => id} = params) do
    with option_value <- OptionValue.get(id),
         {:ok, option_value} <- OptionValue.update(option_value, params) do
      render(conn, "option_value.json", option_value: option_value)
    end
  end
end
