defmodule AdminAppWeb.TemplateApi.OptionTypeController do
  use AdminAppWeb, :controller

  alias AdminAppWeb.TemplateApi.OptionTypeView
  alias Snitch.Core.Tools.MultiTenancy.Repo
  alias Snitch.Data.Model.{VariationTheme, OptionValue}
  import Phoenix.View, only: [render_to_string: 3]

  def index(conn, %{"theme_id" => theme_id} = params) do
    {:ok, theme} = VariationTheme.get(theme_id)
    theme = theme |> Repo.preload(:option_types)

    product_id = params["product_id"]

    html = render_to_string(OptionTypeView, "index.html", theme: theme, product_id: product_id)

    conn
    |> put_status(200)
    |> json(%{html: html})
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, option_value} <- OptionValue.get(id),
         {:ok, option_value} <- OptionValue.update(option_value, params) do
      render(conn, "option_value.json", option_value: option_value)
    end
  end
end
