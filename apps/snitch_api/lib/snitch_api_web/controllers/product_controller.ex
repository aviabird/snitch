defmodule SnitchApiWeb.ProductController do
  use SnitchApiWeb, :controller

  alias Snitch.Data.Model.{Product, ProductReview}
  alias Snitch.Repo
  alias SnitchApi.ProductsContext, as: Context

  plug(SnitchApiWeb.Plug.DataToAttributes)
  action_fallback(SnitchApiWeb.FallbackController)

  def reviews(conn, %{"id" => id}) do
    with product when not is_nil(product) <- Product.get(id) do
      reviews =
        product
        |> Repo.preload(reviews: [rating_option_vote: :rating_option])
        |> Map.take(:reviews)

      render(
        conn,
        SnitchApiWeb.ReviewView,
        "index.json-api",
        data: reviews
      )
    end
  end

  def rating_summary(conn, %{"id" => id}) do
    id = String.to_integer(id)

    with product when not is_nil(product) <- Product.get(id) do
      rating_data = ProductReview.review_aggregate(product)
      render(conn, "rating_summary.json-api", data: rating_data, id: id)
    end
  end

  @include "variants,variants.images"
  def index(conn, params) do
    {products, page} = Context.list_products(conn)
    render(
      conn,
      "index.json-api",
      data: products,
      opts: [include: @include, page: page]
    )
  end

  def show(conn, %{"product_slug" => slug}) do
    product = Context.product_by_slug!(slug)

    render(
      conn,
      "show.json-api",
      data: product,
      opts: [include: @include]
    )
  end
end
