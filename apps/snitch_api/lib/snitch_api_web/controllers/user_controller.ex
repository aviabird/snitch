defmodule SnitchApiWeb.UserController do
  use SnitchApiWeb, :controller

  alias Snitch.Data.Schema.User
  alias SnitchApi.Accounts
  alias SnitchApi.Guardian

  action_fallback(SnitchApiWeb.FallbackController)

  def index(conn, _params) do
    users = Accounts.list_users()
    render(conn, "index.json-api", users: users)
  end

  def create(conn, %{"user" => user_params}) do
    with {:ok, %User{} = user} <- Accounts.create_user(user_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", user_path(conn, :show, user))
      |> render("show.json-api", data: user)
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.token_sign_in(email, password) do
      {:ok, token, _claims} ->
        render(conn, "token.json-api", data: token)

      _ ->
        {:error, :unauthorized}
    end
  end

  def login(conn, _params) do
    {:error, :no_credentials}
  end

  def show(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    render(conn, "show.json-api", data: user)
  end

  def logout(conn, _params) do
    conn
    |> Guardian.Plug.sign_out()
    |> put_status(204)
    |> render(conn, "logut.json-api", nil)
  end
end