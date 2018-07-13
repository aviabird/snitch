defmodule SnitchApiWeb.VariantController do
  use SnitchApiWeb, :controller

<<<<<<< HEAD
  alias Snitch.Data.Model.WishListItem
  alias Snitch.Repo

  def favorite_variants(conn, _params) do
    variants = Repo.all(WishListItem.most_favorited_variants())
    render(conn, "index.json-api", data: variants)
=======
  alias Snitch.Repo
  alias Snitch.Data.Schema.Variant

  def index(conn, %{"product_id" => id}) do
    variants =
      Variant
      |> Repo.all(where: %{product_id: id})
      |> Repo.preload([:images, :shipping_category, :product, stock_items: :stock_location])

    render(
      conn,
      "index.json-api",
      data: variants,
      opts: [include: "images,stock_items,stock_items,shipping_category,product"]
    )
>>>>>>> Products API list/search/filter/pagination/sort
  end
end
