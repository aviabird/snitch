defmodule Snitch.Data.Model.Promotion.EligibilityTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use Snitch.DataCase

  import Snitch.Factory

  alias Snitch.Data.Model.Promotion.Eligibility

  describe "promotion_level_check/1" do
    test "returns true if all checks satisfy" do
      promotion =
        insert(:promotion,
          active?: true,
          starts_at: Timex.shift(DateTime.utc_now(), days: -2),
          expires_at: Timex.shift(DateTime.utc_now(), days: 3),
          usage_limit: 5,
          current_usage_count: 2
        )

      insert(:promotion_order_action, promotion: promotion)

      assert true == Eligibility.promotion_level_check(promotion)
    end

    test "returns false with error if any check fails" do
      promotion =
        insert(:promotion,
          active?: true,
          starts_at: Timex.shift(DateTime.utc_now(), days: -2),
          expires_at: Timex.shift(DateTime.utc_now(), days: 3),
          usage_limit: 5,
          current_usage_count: 2
        )

      ## fails since we have not set any action for the promotion
      assert {false, message} = Eligibility.promotion_level_check(promotion)
      assert message == "promotion is not active"
    end
  end

  describe "order_level_check/2" do
    test "fails as order not in valid state" do
      order = insert(:order, state: :confirmed)
      promotion = insert(:promotion, match_policy: "all")

      assert {false, message} = Eligibility.order_level_check(order, promotion)
      assert message == "promotion not applicable to order"
    end

    test "returns true if all checks apply" do
      %{order: order, promotion: promotion} = set_order_and_promotion()
      assert true == Eligibility.order_level_check(order, promotion)
    end
  end

  def set_order_and_promotion() do
    products = insert_list(3, :product, %{promotionable: true})
    order = insert(:order, state: :delivery)

    [line_items: line_items] =
      line_items(%{order: order, variants: products, line_item_count: length(products)})

    cost =
      Enum.reduce(line_items, Money.new!(currency(), 0), fn item, acc ->
        sum = Money.mult!(item.unit_price, item.quantity)
        Money.add!(acc, sum)
      end)

    promotion = insert(:promotion, match_policy: "any")

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

    %{order: order, promotion: promotion}
  end
end
