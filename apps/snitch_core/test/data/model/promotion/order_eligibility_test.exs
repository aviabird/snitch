defmodule Snitch.Data.Model.Promotion.OrderEligibilityTest do
  @moduledoc false

  use ExUnit.Case
  use Snitch.DataCase
  import Snitch.Factory
  alias Snitch.Data.Model.Promotion.OrderEligibility

  @message %{
    applicable: "promotion applicable",
    valid_state: "valid order state",
    promotionable: "order promotionable"
  }

  describe "valid_order_state/1" do
    test "returns true if order is in valid state for promotion" do
      order = insert(:order, state: :delivery)

      assert {true, message} = OrderEligibility.valid_order_state(order)
      assert message == @message.valid_state
    end

    test "fails if order state not valid for promotion" do
      order = insert(:order, state: :confirmed)

      assert {false, message} = OrderEligibility.valid_order_state(order)
      assert message == "promotion not applicable to order"
    end
  end

  describe "order_promotionable/1" do
    test "returns true if promotionable products found" do
      promo_products = insert_list(2, :product, %{promotionable: true})
      non_promo_product = insert(:product, %{promotionable: false})
      products = [non_promo_product | promo_products]
      order = insert(:order, state: :delivery)

      _set_line_items =
        line_items(%{order: order, variants: products, line_item_count: length(products)})

      assert {true, message} = OrderEligibility.order_promotionable(order)
      assert message == @message.promotionable
    end

    test "returns {false, message} if no promotionable products found" do
      products = insert_list(2, :product, %{promotionable: false})
      order = insert(:order, state: :delivery)

      _set_line_items =
        line_items(%{order: order, variants: products, line_item_count: length(products)})

      assert {false, message} = OrderEligibility.order_promotionable(order)
      assert message == "no promotionable products found"
    end
  end

  describe "rules_check with match_policy 'all'" do
    setup do
      products = insert_list(3, :product, %{promotionable: true})

      order = insert(:order, state: :delivery)

      [line_items: line_items] =
        line_items(%{order: order, variants: products, line_item_count: length(products)})

      total_cost =
        Enum.reduce(line_items, Money.new!(currency(), 0), fn item, acc ->
          sum = Money.mult!(item.unit_price, item.quantity)
          Money.add!(acc, sum)
        end)

      promotion = insert(:promotion, match_policy: "all")

      [order: order, products: products, promotion: promotion, total_cost: total_cost]
    end

    test "returns true as all rules satisfy", context do
      %{promotion: promotion, order: order, products: products, total_cost: cost} = context
      product_ids = Enum.map(products, fn p -> p.id end)

      insert(:order_total_rule,
        promotion: promotion,
        preferences: %{lower_range: Decimal.sub(cost.amount, 1), upper_range: 0.0}
      )

      insert(:product_rule,
        promotion: promotion,
        preferences: %{match_policy: "all", product_list: product_ids}
      )

      assert {true, _message} = OrderEligibility.rules_check(order, promotion)
    end

    test "fails as all rules don't satisfy", context do
      %{promotion: promotion, order: order, products: products, total_cost: cost} = context
      product_ids = Enum.map(products, fn p -> p.id end)

      insert(:order_total_rule,
        promotion: promotion,
        preferences: %{lower_range: Decimal.add(cost.amount, 1), upper_range: 0.0}
      )

      insert(:product_rule,
        promotion: promotion,
        preferences: %{match_policy: "all", product_list: product_ids}
      )

      assert {false, message} = OrderEligibility.rules_check(order, promotion)
      assert message == "order doesn't falls under the item total condition"
    end
  end

  describe "rules_check with match_policy 'any'" do
    setup do
      products = insert_list(3, :product, %{promotionable: true})

      order = insert(:order, state: :delivery)

      [line_items: line_items] =
        line_items(%{order: order, variants: products, line_item_count: length(products)})

      total_cost =
        Enum.reduce(line_items, Money.new!(currency(), 0), fn item, acc ->
          sum = Money.mult!(item.unit_price, item.quantity)
          Money.add!(acc, sum)
        end)

      promotion = insert(:promotion, match_policy: "any")

      [order: order, products: products, promotion: promotion, total_cost: total_cost]
    end

    test "return true as one of the rules satisfy", context do
      %{promotion: promotion, order: order, products: products, total_cost: cost} = context
      product_ids = Enum.map(products, fn p -> p.id end)

      # item total rule will fail as lower_range is more than total
      insert(:order_total_rule,
        promotion: promotion,
        preferences: %{lower_range: Decimal.add(cost.amount, 1), upper_range: 0.0}
      )

      insert(:product_rule,
        promotion: promotion,
        preferences: %{match_policy: "all", product_list: product_ids}
      )

      assert {true, _message} = OrderEligibility.rules_check(order, promotion)
    end

    test "return false as none of the rules satisfy", context do
      %{promotion: promotion, order: order, total_cost: cost} = context
      new_product = insert(:product)

      # item total rule will fail as lower_range is more than total
      insert(:order_total_rule,
        promotion: promotion,
        preferences: %{lower_range: Decimal.add(cost.amount, 1), upper_range: 0.0}
      )

      # fails as order does not contain products of rule
      insert(:product_rule,
        promotion: promotion,
        preferences: %{match_policy: "all", product_list: [new_product.id]}
      )

      assert {false, _message} = OrderEligibility.rules_check(order, promotion)
    end
  end
end
