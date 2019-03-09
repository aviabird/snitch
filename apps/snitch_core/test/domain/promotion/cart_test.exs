defmodule Snitch.Domain.Promotion.CartHelperTest do
  use ExUnit.Case
  use Snitch.DataCase
  import Snitch.Factory
  alias Snitch.Domain.Promotion.CartHelper
  alias Snitch.Data.Model.{Promotion, PromotionAdjustment, LineItem}

  describe "evaluate_promotion/1" do
    test "all adjustments are removed if promotion becomes ineligible" do
      item_info = %{quantity: 2, price: Money.new!(currency(), 10)}

      %{order: order, line_items: line_items, order_total: order_total, product_ids: product_ids} =
        setup_order(item_info)

      [line_item_1, _, _] = line_items

      order_params = %{order: order, order_total: order_total, product_ids: product_ids}
      apply_promotion(order_params)

      adjustments = PromotionAdjustment.order_adjustments(order)

      assert adjustments != []

      Enum.each(adjustments, fn adj ->
        assert adj.eligible == true
      end)

      # Remove a line item such that order becomes ineligible for promotion.
      LineItem.delete(line_item_1)

      assert {:ok, _data} = CartHelper.evaluate_promotion(order)
      adjustments = PromotionAdjustment.order_adjustments(order)
      assert adjustments == []
    end

    test "returns 'no promotion found' if promotion not applied on order" do
      item_info = %{quantity: 2, price: Money.new!(currency(), 10)}
      %{order: order} = setup_order(item_info)

      assert {:error, message} = CartHelper.evaluate_promotion(order)
      assert message == "no promotion applied to order"
    end

    test "new adjustments created for order as line items touched" do
      item_info = %{quantity: 2, price: Money.new!(currency(), 10)}

      %{order: order, line_items: line_items, order_total: order_total, product_ids: product_ids} =
        setup_order(item_info)

      [line_item_1, _, _] = line_items

      order_params = %{order: order, order_total: order_total, product_ids: product_ids}
      apply_promotion(order_params)

      adjustments = PromotionAdjustment.order_adjustments(order)

      assert adjustments != []

      Enum.each(adjustments, fn adj ->
        assert adj.eligible == true
      end)

      LineItem.update(line_item_1, %{quantity: 3})
      assert {:ok, _data} = CartHelper.evaluate_promotion(order)

      new_adjustments = PromotionAdjustment.order_adjustments(order)
      assert MapSet.disjoint?(MapSet.new(adjustments), MapSet.new(new_adjustments))
    end
  end

  defp apply_promotion(order_params) do
    action_manifest = %{order_action: Decimal.new(10), line_item_action: Decimal.new(10)}
    %{order: order, order_total: order_total, product_ids: product_ids} = order_params

    item_total_cost = Decimal.sub(order_total.amount, 1)

    rule_manifest = %{item_total_cost: item_total_cost, product_ids: product_ids}

    promotion = insert(:promotion)
    set_rules_and_actions(promotion, rule_manifest, action_manifest)

    {:ok, _message} = Promotion.apply(order, promotion.code)

    %{promotion: promotion}
  end

  defp set_rules_and_actions(promotion, rule_manifest, action_manifest) do
    %{item_total_cost: cost, product_ids: product_ids} = rule_manifest
    %{order_action: order_action_data, line_item_action: line_item_action_data} = action_manifest

    insert(:order_total_rule,
      promotion: promotion,
      preferences: %{lower_range: cost, upper_range: Decimal.new(0)}
    )

    insert(:product_rule,
      promotion: promotion,
      preferences: %{match_policy: "all", product_list: product_ids}
    )

    insert(:promotion_order_action,
      preferences: %{
        calculator_module: "Elixir.Snitch.Domain.Calculator.FlatRate",
        calculator_preferences: %{amount: order_action_data}
      },
      promotion: promotion
    )

    insert(:promotion_line_item_action,
      preferences: %{
        calculator_module: "Elixir.Snitch.Domain.Calculator.FlatRate",
        calculator_preferences: %{amount: line_item_action_data}
      },
      promotion: promotion
    )
  end

  defp setup_order(item_info) do
    %{quantity: quantity, price: price} = item_info

    products = insert_list(3, :product, promotionable: true, selling_price: price)

    order = insert(:order, state: "delivery")

    line_items =
      Enum.map(products, fn product ->
        insert(:line_item,
          order: order,
          product: product,
          quantity: quantity,
          unit_price: product.selling_price
        )
      end)

    cost =
      Enum.reduce(line_items, Money.new!(currency(), 0), fn item, acc ->
        sum = Money.mult!(item.unit_price, item.quantity)
        Money.add!(acc, sum)
      end)

    product_ids = Enum.map(products, fn product -> product.id end)

    %{
      order: order,
      line_items: line_items,
      products: products,
      product_ids: product_ids,
      order_total: cost
    }
  end
end
