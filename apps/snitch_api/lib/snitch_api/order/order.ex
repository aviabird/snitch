defmodule SnitchApi.Order do
  @moduledoc """
  The Checkout context.
  """

  import Ecto.Query

  alias Snitch.Core.Tools.MultiTenancy.Repo
  alias Snitch.Data.Model.LineItem, as: LineItemModel
  alias Snitch.Data.Schema.Order, as: OrderSchema
  alias BeepBop.Context
  alias Snitch.Data.Model.{Order, PaymentMethod}
  alias Snitch.Data.Schema.LineItem
  alias Snitch.Domain.Order.DefaultMachine
  alias Snitch.Domain.Order, as: OrderDomain

  @doc """
  Attaching address to order.

  Updates order with the supplied billing and shipping address.
  """

  def attach_address(order_id, shipping_address, billing_address) do
    {:ok, order} = Order.get(order_id)
    order = order |> Repo.preload([:payments, :packages])

    context =
      order
      |> Context.new(
        state: %{
          billing_address: billing_address,
          shipping_address: shipping_address
        }
      )

    transition = transition_to_address(order.state, context)
    transition_response(transition, order_id)
  end

  def load_order(order_id) do
    {:ok, order} = Order.get(order_id)
    line_item_query = from(LineItem, order_by: [desc: :inserted_at], preload: [product: :theme])
    Repo.preload(order, line_items: line_item_query)
  end

  ####################### line item helpers ############################

  def add_to_cart(line_item) do
    case get_line_item(line_item["order_id"], line_item["product_id"]) do
      [] -> LineItemModel.create(line_item)
      [l | _] -> update_line_item(l, line_item)
    end
  end

  defp get_line_item(order_id, product_id) do
    query = from(l in LineItem, where: l.order_id == ^order_id and l.product_id == ^product_id)
    Repo.all(query)
  end

  defp update_line_item(line_item, params) do
    new_count = line_item.quantity + params["quantity"]
    new_params = %{params | "quantity" => new_count}
    LineItemModel.update(line_item, new_params)
  end

  def delete_line_item(line_item_id) do
    with {:ok, %LineItem{} = line_item} <- LineItemModel.get(line_item_id),
         {:ok, _} <- LineItemModel.delete(line_item) do
      {:ok, line_item}
    else
      {:error, _} -> {:error, :not_found}
    end
  end

  #################### order transition helpers #######################

  def add_payment(order_id, payment_method_id) do
    with {:ok, order} <- Order.get(order_id),
         {:ok, payment_method} <- PaymentMethod.get(payment_method_id) do
      amount = OrderDomain.total_amount(order)

      context =
        order
        |> Context.new(
          state: %{
            payment_method: payment_method,
            payment_params: %{
              payment_params: %{
                amount: amount
              },
              subtype_params: %{}
            }
          }
        )

      transition = DefaultMachine.add_payment(context)
      transition_response(transition, order_id)
    else
      {:error, msg} ->
        {:error, msg}
    end
  end

  def add_shipments(order_id, []) do
    with {:ok, order} <- Order.get(order_id) do
      order = Repo.preload(order, packages: :items)
      shipping_preferences = package_manifest(order.packages)

      context =
        Context.new(
          order,
          state: %{
            shipping_preferences: shipping_preferences
          }
        )

      transition = DefaultMachine.add_shipments(context)
      transition_response(transition, order.id)
    else
      {:error, msg} ->
        {:error, msg}
    end
  end

  def add_shipments(order_id, packages) do
    with {:ok, %OrderSchema{} = order} <- Order.get(order_id),
         preloaded_order <- order |> Repo.preload(packages: :items),
         true <- length(packages) == length(preloaded_order.packages) do
      shipping_preferences = parse_package_params(packages)

      context =
        Context.new(
          preloaded_order,
          state: %{
            shipping_preferences: shipping_preferences
          }
        )

      transition = DefaultMachine.add_shipments(context)
      transition_response(transition, order.id)
    else
      {:error, msg} ->
        {:error, msg}

      _ ->
        {:error, "package list does not equal all order packages"}
    end
  end

  defp transition_response(%Context{errors: nil}, order_id) do
    {:ok, order} = Order.get(order_id)
    order = order |> Repo.preload(line_items: [product: [:theme, [options: :option_type]]])

    {:ok, order}
  end

  defp transition_response(%Context{errors: errors}, _) do
    {:error, message} = errors
    {:error, %{message: message}}
  end

  defp transition_to_address(:cart, context) do
    DefaultMachine.add_addresses(context)
  end

  defp transition_to_address(:address, context) do
    DefaultMachine.delivery_to_address(context)
  end

  defp transition_to_address(:delivery, context) do
    DefaultMachine.delivery_to_address(context)
  end

  defp transition_to_address(:payment, context) do
    DefaultMachine.payment_to_address(context)
  end

  defp package_manifest(packages) do
    Enum.map(packages, fn %{id: id, shipping_methods: methods} ->
      shipping_mehod = List.first(methods)
      %{package_id: id, shipping_method_id: shipping_mehod.id}
    end)
  end

  defp parse_package_params(packages) do
    Enum.map(packages, fn package ->
      %{
        package_id: String.to_integer(package["package_id"]),
        shipping_method_id: String.to_integer(package["shipping_method_id"])
      }
    end)
  end
end
