defmodule AdminAppWeb.VariationThemeController do
  use AdminAppWeb, :controller

  alias Snitch.Data.Model.VariationTheme, as: VTModel
  alias Snitch.Data.Schema.VariationTheme, as: VTSchema
  alias Snitch.Data.Model.Option, as: OptionModel

  plug(:load_resources when action in [:new, :edit, :update, :create])

  def index(conn, _params) do
    themes = VTModel.get_all()
    render(conn, "index.html", themes: themes)
  end

  def new(conn, _params) do
    changeset = VTSchema.create_changeset(%VTSchema{}, %{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"variation_theme" => params}) do
    case VTModel.create(params) do
      {:ok, _} ->
        themes = VTModel.get_all()
        render(conn, "index.html", themes: themes)

      {:error, changeset} ->
        render(conn, "new.html", changeset: %{changeset | action: :new})
    end
  end

  def edit(conn, %{"id" => id}) do
    case VTModel.get(id) do
      {:ok, %VTSchema{} = theme} ->
        changeset = VTSchema.update_changeset(theme, %{})
        render(conn, "edit.html", changeset: changeset)

      {:error, _} ->
        conn
        |> put_flash(:info, "Variation theme not found")
        |> redirect(to: variation_theme_path(conn, :index))
    end
  end

  def update(conn, %{"id" => id, "variation_theme" => params}) do
    with {:ok, %VTSchema{} = theme} <- VTModel.get(id),
         {:ok, _} <- VTModel.update(theme, params) do
      themes = VTModel.get_all()
      render(conn, "index.html", themes: themes)
    else
      {:error, :variation_theme_not_found} ->
        conn
        |> put_flash(:info, "Variation theme not found")
        |> redirect(to: variation_theme_path(conn, :index))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: %{changeset | action: :edit})
    end
  end

  def delete(conn, %{"id" => id}) do
    case VTModel.delete(id) do
      {:ok, theme} ->
        conn
        |> put_flash(:info, "Variation theme #{theme.name} deleted successfully")
        |> redirect(to: variation_theme_path(conn, :index))

      {:error, _} ->
        conn
        |> put_flash(:error, "Failed to delete Variation theme")
        |> redirect(to: variation_theme_path(conn, :index))
    end
  end

  defp load_resources(conn, _opts) do
    assign(conn, :option_types, OptionModel.get_all())
  end
end
