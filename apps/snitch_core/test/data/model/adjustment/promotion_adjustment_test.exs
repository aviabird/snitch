defmodule Snitch.Data.Model.PromotionAdjustmentTest do
  @moduledoc false

  use ExUnit.Case
  use Snitch.DataCase
  import Snitch.Factory
  alias Snitch.Data.Model.{Promotion, PromotionAdjustment, Adjustment}

  describe "promotion adjustment queries" do
    setup do
      products = insert_list(3, :product, %{promotionable: true})
      order = insert(:order, state: :delivery)
      product_ids = Enum.map(products, fn p -> p.id end)

      [line_items: line_items] =
        line_items(%{order: order, variants: products, line_item_count: length(products)})

      cost =
        Enum.reduce(line_items, Money.new!(currency(), 0), fn item, acc ->
          sum = Money.mult!(item.unit_price, item.quantity)
          Money.add!(acc, sum)
        end)

      promotion1 = insert(:promotion)
      set_rules_and_actions(promotion1, cost, product_ids)

      promotion2 = insert(:promotion, code: "DIWALI50")
      set_rules_and_actions(promotion2, cost, product_ids)

      [order: order, promotion1: promotion1, promotion2: promotion2]
    end

    test "order_adjustments/1", context do
      %{order: order, promotion1: promotion1, promotion2: promotion2} = context

      # since promotion is applied twice there should be 8 adjustments
      # promotion1 -> 1 order + 3 lineitems = 4
      # promotion2 -> 1 order + 3 lineitems = 4
      Promotion.activate?(order, promotion1)
      Promotion.activate?(order, promotion2)

      data = PromotionAdjustment.order_adjustments(order)
      assert length(data) == 8
    end

    test "order_adjustments_for_promotion/2", context do
      %{order: order, promotion1: promotion1, promotion2: promotion2} = context

      # since two promotions are applied twice there should be 8 adjustments
      # promotion1 -> 1 order + 3 lineitems = 4
      # promotion2 -> 1 order + 3 lineitems = 4
      Promotion.activate?(order, promotion1)
      Promotion.activate?(order, promotion2)

      # data is returned only for promotion 1
      data1 = PromotionAdjustment.order_adjustments_for_promotion(order, promotion1)
      assert length(data1) == 4

      data2 = PromotionAdjustment.order_adjustments_for_promotion(order, promotion2)
      assert length(data2) == 4
    end

    test "eligible_order_adjustments/1", context do
      %{order: order, promotion1: promotion1, promotion2: promotion2} = context

      # since promotion is applied twice there should be 8 adjustments
      # promotion1 -> 1 order + 3 lineitems = 4
      Promotion.activate?(order, promotion1)
      Promotion.activate?(order, promotion2)

      # data is returned only for promotion 1
      adjustments = PromotionAdjustment.order_adjustments_for_promotion(order, promotion1)
      data = PromotionAdjustment.eligible_order_adjustments(order)
      assert data == []

      # activate adjustments for promotion1
      {:ok, _data} = PromotionAdjustment.process_adjustments(order, promotion1)

      data = PromotionAdjustment.eligible_order_adjustments(order)
      assert length(data) == 4
    end
  end

  defp set_rules_and_actions(promotion, cost, product_ids) do
    insert(:order_total_rule,
      promotion: promotion,
      preferences: %{lower_range: Decimal.sub(cost.amount, 1), upper_range: Decimal.new(0)}
    )

    insert(:product_rule,
      promotion: promotion,
      preferences: %{match_policy: "all", product_list: product_ids}
    )

    insert(:promotion_order_action, promotion: promotion)
    insert(:promotion_line_item_action, promotion: promotion)
  end
end
