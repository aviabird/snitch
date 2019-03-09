defmodule SnitchApiWeb.LineItemController do
  use SnitchApiWeb, :controller

  alias Snitch.Data.Model.LineItem, as: LineItemModel
  alias Snitch.Data.Model.Order, as: OrderModel
  alias Snitch.Data.Schema.{LineItem, Product}
  alias Snitch.Core.Tools.MultiTenancy.Repo
  alias SnitchApi.Order, as: OrderContext

  plug(SnitchApiWeb.Plug.DataToAttributes)
  plug(SnitchApiWeb.Plug.LoadUser)
  action_fallback(SnitchApiWeb.FallbackController)

  def create(conn, %{"product_id" => product_id} = params) do
    %{selling_price: selling_price} = Repo.get(Product, product_id)
    line_item = Map.put(params, "unit_price", selling_price)

    with {:ok, line_item} <- OrderContext.add_to_cart(line_item) do
      order = OrderContext.load_order(params["order_id"])

      conn
      |> put_status(200)
      |> put_resp_header("location", line_item_path(conn, :show, line_item.id))
      |> render(
        SnitchApiWeb.OrderView,
        "show.json-api",
        data: order,
        opts: [
          include: "line_items,line_items.product"
        ]
      )
    end
  end

  def guest_line_item(conn, %{"order_id" => order_id} = params) do
    with {:ok, line_item} <- add_line_item(params) do
      order = OrderContext.load_order(order_id)

      conn
      |> put_status(200)
      |> put_resp_header("location", line_item_path(conn, :show, line_item.id))
      |> render(
        SnitchApiWeb.OrderView,
        "show.json-api",
        data: order,
        opts: [
          include: "line_items,line_items.product"
        ]
      )
    end
  end

  def guest_line_item(conn, params) do
    with {:ok, blank_order} <- OrderModel.create_guest_order(),
         params <- Map.put(params, "order_id", blank_order.id),
         {:ok, line_item} <- add_line_item(params) do
      order = OrderContext.load_order(line_item.order_id)

      conn
      |> put_status(200)
      |> put_resp_header("location", line_item_path(conn, :show, line_item.id))
      |> render(
        SnitchApiWeb.OrderView,
        "show.json-api",
        data: order,
        opts: [
          include: "line_items,line_items.product"
        ]
      )
    end
  end

  def add_line_item(params) do
    %{selling_price: selling_price} = Repo.get(Product, params["product_id"])
    line_item = Map.put(params, "unit_price", selling_price)

    OrderContext.add_to_cart(line_item)
  end

  def delete(conn, %{"id" => line_item_id}) do
    case OrderContext.delete_line_item(line_item_id) do
      {:ok, _} ->
        conn
        |> put_status(204)
        |> send_resp(:no_content, "")
    end
  end

  def update(conn, %{"id" => id} = params) do
    line_item = Repo.get(LineItem, id)

    with {:ok, line_item} <- LineItemModel.update(line_item, params) do
      line_item = line_item |> Repo.preload(:product)

      conn
      |> put_status(200)
      |> put_resp_header("location", line_item_path(conn, :show, line_item))
      |> render("show.json-api", data: line_item)
    end
  end

  def show(conn, %{"id" => id}) do
    case LineItemModel.get(id) do
      {:error, :line_item_not_found} ->
        conn
        |> put_status(204)
        |> render("show.json-api", data: [])

      {:ok, line_item} ->
        conn
        |> put_status(200)
        |> render("show.json-api", data: line_item)
    end
  end
end
