defmodule AdminAppWeb.OptionTypeController do
  use AdminAppWeb, :controller
  alias Snitch.Data.Model.Option, as: OptionModel
  alias Snitch.Data.Schema.Option, as: OptionSchema

  def index(conn, _params) do
    option_types = OptionModel.get_all()
    render(conn, "index.html", %{option_types: option_types})
  end

  def new(conn, _params) do
    changeset = OptionSchema.create_changeset(%OptionSchema{}, %{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"option_type" => params}) do
    case OptionModel.create(params) do
      {:ok, _} ->
        option_types = OptionModel.get_all()
        render(conn, "index.html", %{option_types: option_types})

      {:error, changeset} ->
        render(conn, "new.html", changeset: %{changeset | action: :new})
    end
  end

  def edit(conn, %{"id" => id}) do
    with {id, _} <- Integer.parse(id),
         {:ok, %OptionSchema{} = option_type} <- OptionModel.get(id) do
      changeset = OptionSchema.update_changeset(option_type, %{})
      render(conn, "edit.html", changeset: changeset)
    else
      err when err in [:error, nil] ->
        conn
        |> put_flash(:info, "Option Type not found")
        |> redirect(to: option_type_path(conn, :index))
    end
  end

  def update(conn, %{"id" => id, "option_type" => params}) do
    with {id, _} <- Integer.parse(id),
         {:ok, option_type} <- OptionModel.get(id),
         {:ok, _} <- OptionModel.update(option_type, params) do
      option_types = OptionModel.get_all()
      render(conn, "index.html", %{option_types: option_types})
    else
      {:error, changeset} ->
        render(conn, "edit.html", changeset: %{changeset | action: :edit})

      :error ->
        conn
        |> halt()
        |> put_flash(:info, "Option Type not found")
        |> redirect(to: option_type_path(conn, :index))
    end
  end

  def delete(conn, %{"id" => id}) do
    with {id, _} <- Integer.parse(id),
         false <- OptionModel.is_theme_associated(id),
         {:ok, option_type} <- OptionModel.delete(id) do
      conn
      |> put_flash(:info, "Option type #{option_type.name} deleted successfully")
      |> redirect(to: option_type_path(conn, :index))
    else
      true ->
        conn
        |> put_flash(:error, "Option type associated to variation theme. Deletion not allowed")
        |> redirect(to: option_type_path(conn, :index))

      {:error, _} ->
        conn
        |> put_flash(:error, "Failed to delete option type")
        |> redirect(to: option_type_path(conn, :index))

      :error ->
        conn
        |> halt()
        |> put_flash(:info, "Option Type not found")
        |> redirect(to: option_type_path(conn, :index))
    end
  end
end
