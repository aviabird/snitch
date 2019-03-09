defmodule Snitch.Data.Model.OrderTest do
  use ExUnit.Case, async: true
  use Snitch.DataCase

  import Snitch.Factory

  alias Snitch.Data.Model.{LineItem, Order}

  setup :variants
  setup :user_with_address
  setup :line_item_params
  setup :order_params

  describe "create/3" do
    test "with valid data", %{order_params: params, variants: vs} do
      {:ok, order} = Order.create(params)
      assert length(order.line_items) == length(vs)
    end

    test "without line_items", %{order_params: params} do
      {:ok, order} =
        params
        |> Map.put(:line_items, [])
        |> Order.create()

      assert [] = order.line_items
    end
  end

  describe "create_for_guest/3" do
    test "with valid data", %{order_params: params, variants: vs} do
      {:ok, order} = Order.create(params)
      assert length(order.line_items) == length(vs)
    end

    test "without line_items", %{order_params: params} do
      {:ok, order} =
        params
        |> Map.put(:line_items, [])
        |> Order.create()

      assert [] = order.line_items
    end
  end

  describe "update/3" do
    test "add some line_items", %{order_params: order_params} do
      {:ok, order} = Order.create(order_params)
      new_variant = insert(:variant)
      old_line_items = extract_ids(order.line_items)
      line_items = [%{product_id: new_variant.id, quantity: 1} | old_line_items]

      {:ok, %{line_items: new_items}} = Order.update(%{line_items: line_items}, order)
      assert Enum.count(new_items) == 4
      assert Enum.all?(old_line_items, fn x -> x in extract_ids(new_items) end)
    end

    test "remove some line_items", %{order_params: order_params} do
      {:ok, order} = Order.create(order_params)

      [line_item | _] = order.line_items

      {:ok, %{line_items: new_items}} =
        Order.update(
          %{line_items: [%{id: line_item.id}]},
          order
        )

      assert Enum.count(new_items) == 1
    end

    test "remove all line_items", %{order_params: order_params} do
      {:ok, order} = Order.create(order_params)

      assert {:ok, %{line_items: []}} =
               Order.update(
                 %{line_items: []},
                 order
               )
    end

    test "update few items", %{order_params: order_params} do
      {:ok, order} = Order.create(order_params)

      [one, two, three] = extract_ids(order.line_items, [:quantity, :product_id])

      params = %{
        line_items: [%{one | quantity: 42}, two, %{three | quantity: 1}]
      }

      {:ok, %{line_items: new_items}} = Order.update(params, order)
      assert Enum.map(new_items, &Map.fetch!(&1, :quantity)) == [42, 2, 1]
    end

    test "update one, add one, remove one, retain one", %{order_params: order_params} do
      {:ok, order} = Order.create(order_params)

      new_variant = insert(:variant)
      [_, two, three] = extract_ids(order.line_items, [:quantity, :product_id])

      params = %{
        line_items: [%{two | quantity: 42}, three, %{product_id: new_variant.id, quantity: 3}]
      }

      {:ok, %{line_items: new_items}} = Order.update(params, order)
      assert Enum.map(new_items, &Map.fetch!(&1, :quantity)) == [42, 2, 3]
    end

    test "orders related to user", %{order_params: order_params} do
      {:ok, order} = Order.create(order_params)
      user = order.user_id

      user_order =
        user
        |> Order.user_orders()
        |> List.first()

      assert order.id == user_order.id
    end
  end

  describe "partial_update/2" do
    test "params only", %{order_params: order_params} do
      {:ok, order} = Order.create(order_params)

      {:ok, new_order} = Order.partial_update(order, %{state: :address})
      assert extract_ids(order.line_items) == extract_ids(new_order.line_items)
      assert new_order.state == :address
    end
  end

  describe "order" do
    test "count by state", %{order_params: params} do
      {:ok, order} = Order.create(params)
      Order.partial_update(order, %{state: :confirmed})

      next_date =
        order.inserted_at
        |> NaiveDateTime.to_date()
        |> Date.add(1)
        |> Date.to_string()
        |> get_naive_date_time()

      order_state_count =
        Order.get_order_count_by_state(order.inserted_at, next_date) |> List.first()

      assert order_state_count.count == 1
      assert order_state_count.state == :confirmed
    end

    test "count by date", %{order_params: params} do
      {:ok, order} = Order.create(params)

      next_date =
        order.inserted_at
        |> NaiveDateTime.to_date()
        |> Date.add(1)
        |> Date.to_string()
        |> get_naive_date_time()

      order_date_count =
        Order.get_order_count_by_date(order.inserted_at, next_date) |> List.first()

      assert order_date_count.count == 1
    end
  end

  describe "user_order/1" do
    test "returns same order if, it's in non complete state" do
      user = insert(:user)
      order = insert(:order, user: user, state: :cart)

      assert {:ok, user_order} = Order.user_order(user.id)
      assert user_order.id == order.id
    end

    test "returns new order if, order in any completed state" do
      user = insert(:user)
      order = insert(:order, user: user, state: :confirmed)

      assert {:ok, user_order} = Order.user_order(user.id)
      assert user_order.id != order.id
    end
  end

  defp get_naive_date_time(date) do
    Date.from_iso8601(date)
    |> elem(1)
    |> NaiveDateTime.new(~T[00:00:00])
    |> elem(1)
  end

  defp line_item_params(%{variants: variants}) do
    line_items =
      variants
      |> Enum.reduce([], fn v, acc ->
        [%{product_id: v.id, quantity: 2} | acc]
      end)
      |> LineItem.update_unit_price()

    [line_items: line_items]
  end

  defp order_params(%{user: user, line_items: li}) do
    [
      order_params: %{
        user_id: user.id,
        number: "long_unique_number",
        line_items: li
      }
    ]
  end

  # This guys does some magic. Builds a list of transform functions, one for each
  # `key` in `others`.
  defp extract_ids(items, others \\ []) do
    transforms =
      Enum.map(others, fn key ->
        fn acc, struct ->
          value = Map.fetch!(struct, key)
          Map.put(acc, key, value)
        end
      end)

    Enum.reduce(items, [], fn x, acc ->
      datum = Enum.reduce(transforms, %{id: x.id}, fn t, acc -> t.(acc, x) end)
      [datum | acc]
    end)
  end
end
