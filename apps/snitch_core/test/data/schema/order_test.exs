defmodule Snitch.Data.Schema.OrderTest do
  use ExUnit.Case, async: true
  use Snitch.DataCase

  import Snitch.Factory

  alias Snitch.Data.Model.LineItem
  alias Snitch.Data.Schema.Order

  @address_params %{
    first_name: "Tony",
    last_name: "Stark",
    address_line_1: "10-8-80 Malibu Point",
    zip_code: "90265",
    city: "Malibu",
    phone: "1234567890",
    state: nil,
    state_id: nil,
    country: nil,
    country_id: nil
  }

  @order_params %{
    line_items: nil,
    user_id: nil
  }

  setup :variants

  describe "create_changeset/2" do
    setup :user_with_address

    test "both order and line_items are inserted to DB", context do
      %{user: user, variants: variants} = context
      line_items = line_item_params(variants)

      params = %{
        @order_params
        | user_id: user.id,
          line_items: line_items
      }

      cs = Order.create_changeset(build(:order), params)

      assert cs.valid?
      assert %{line_items: _, user_id: _} = cs.changes
      assert Enum.all?(cs.changes.line_items, fn %{action: action} -> action == :insert end)
      assert {:ok, _} = Repo.insert(cs)
    end

    test "order can handle duplicate line_items", %{user: user, variants: [v | _]} do
      params = %{
        @order_params
        | user_id: user.id,
          line_items: line_item_params([v, v])
      }

      cs = Order.create_changeset(build(:order), params)

      refute cs.valid?
      assert %{line_items: line_item_changesets, user_id: _} = cs.changes
      assert Enum.all?(line_item_changesets, fn %{valid?: validity} -> validity end)
      assert %{line_items: ["line_items must have unique variant_ids"]} = errors_on(cs)
    end

    test "order can be created without line_items", %{user: user} do
      params = %{
        @order_params
        | user_id: user.id,
          line_items: []
      }

      cs = Order.create_changeset(build(:order), params)
      assert cs.valid?
    end

    test "fails for non-existent user_id", %{user: user} do
      params = %{
        @order_params
        | user_id: -1,
          line_items: []
      }

      cs = Order.create_changeset(%Order{}, params)
      {:error, changeset} = Repo.insert(cs)
      assert %{user_id: ["does not exist"]} == errors_on(changeset)
    end
  end

  describe "create_for_guest_changeset/2" do
    test "with no params" do
      cs = Order.create_for_guest_changeset(build(:order), %{})
      assert cs.valid?
    end

    test "fails without state" do
      cs = Order.create_for_guest_changeset(%Order{state: nil}, %{})
      refute cs.valid?
      assert %{state: ["can't be blank"]} == errors_on(cs)
    end
  end

  describe "update_changeset/2" do
    setup %{variants: variants} do
      line_items = line_item_params(variants)

      params = %{
        @order_params
        | user_id: -1,
          line_items: line_items
      }

      [
        persisted:
          :order
          |> insert(line_items: [])
          |> Order.update_changeset(params)
          |> Repo.update!()
      ]
    end

    test "unassociated line_items", context do
      %{persisted: persisted, variants: variants} = context
      params = %{line_items: line_item_params(variants)}
      cs = Order.update_changeset(persisted, params)

      %{valid?: validity, changes: changes} = cs

      assert validity
      # 3 old LIs replaced (aka deleted) and 3 new inserted.
      assert Enum.all?(changes.line_items, fn x -> x.action in [:insert, :replace] end)
      assert {:ok, _order} = Repo.update(cs)
    end

    test "quantity, variant", context do
      %{persisted: persisted} = context
      [one, two, three] = persisted.line_items

      line_items =
        LineItem.update_unit_price([
          %{id: two.id, product_id: two.product_id, quantity: 9},
          %{id: one.id, product_id: three.product_id, quantity: one.quantity},
          %{id: three.id, product_id: one.product_id, quantity: three.quantity}
        ])

      params = %{line_items: line_items}
      cs = Order.update_changeset(persisted, params)
      %{valid?: validity, changes: changes} = cs

      assert validity
      assert Enum.all?(changes.line_items, fn x -> x.action == :update end)
      assert {:ok, _order} = Repo.update(cs)
    end

    test "no changes, bud!", context do
      %{persisted: persisted} = context
      [one, two, three] = persisted.line_items

      line_items = LineItem.update_unit_price([%{id: one.id}, %{id: two.id}, %{id: three.id}])

      params = %{line_items: line_items}

      cs = Order.update_changeset(persisted, params)

      %{valid?: validity, changes: changes} = cs
      assert validity
      assert changes == %{}
      assert {:ok, _order} = Repo.update(cs)
    end
  end

  describe "partial_update_changeset" do
    setup do
      [
        persisted: insert(:order, shipping_address: nil, billing_address: nil),
        address: insert(:address)
      ]
    end

    test "fails with bad address params", %{persisted: persisted, address: address} do
      address_params = %{
        @address_params
        | country_id: address.country.id,
          state_id: -1
      }

      params = %{
        shipping_address: address_params,
        billing_address: address_params
      }

      cs = Order.partial_update_changeset(persisted, params)
      refute cs.valid?

      assert %{
               shipping_address: %{state_id: ["does not exist"]},
               billing_address: %{state_id: ["does not exist"]}
             } = errors_on(cs)
    end

    test "with valid address params", %{persisted: persisted, address: address} do
      address_params = %{
        @address_params
        | country_id: address.country.id,
          state_id: address.state.id
      }

      params = %{
        shipping_address: address_params,
        billing_address: address_params,
        promo_total: Money.zero(:INR)
      }

      cs = Order.partial_update_changeset(persisted, params)
      assert cs.valid?
      assert {:ok, _} = Repo.update(cs)
    end
  end

  defp line_item_params([]), do: []

  defp line_item_params(variants) do
    line_items =
      variants
      |> Stream.map(fn x -> x.id end)
      |> Enum.into([], fn variant_id ->
        %{product_id: variant_id, quantity: 2}
      end)

    LineItem.update_unit_price(line_items)
  end
end

defmodule Snitch.Data.Schema.OrderDocTest do
  use ExUnit.Case, async: true
  use Snitch.DataCase

  import Snitch.Factory

  setup do
    insert(:variant)
    :ok
  end

  doctest Snitch.Data.Schema.Order
end
