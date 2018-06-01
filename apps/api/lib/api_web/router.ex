defmodule ApiWeb.Router do
  use ApiWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api/v1", ApiWeb, as: :api_v1 do
    pipe_through(:api)

    get("/taxonomies", TaxonomyController, :index)

    post("orders.json", OrderController, :create)

    scope("/orders") do
      get("/current/:id", OrderController, :current)
      get("/:order_number/payments/new", PaymentController, :payment_methods)
      post("/:order_number/line_items/", OrderController, :add_line_item)
    end

    resources("/orders", OrderController, only: [:create]) do
      resources("/payments", PaymentController, only: [:new, :create])
    end

    resources("/products", ProductController, only: [:index, :show])

    scope("/checkouts") do
      put("/:order_id/next.json", CheckoutController, :next)
      put("/*order_id", CheckoutController, :add_addresses)
    end
  end
end
