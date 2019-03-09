defmodule Snitch.Data.Model.Promotion.OrderEligibility do
  @moduledoc """
  Defines functions for order level checks while checking if
  a promotion can be applied to the order.
  """
  use Snitch.Data.Model
  alias Snitch.Data.Model.PromotionAdjustment

  @valid_order_states ~w(delivery address cart)a
  @success_message "promotion applicable"
  @error_message "coupon not applicable"
  @coupon_applied "coupon already applied"

  @message %{
    applicable: "promotion applicable",
    valid_state: "valid order state",
    promotionable: "order promotionable"
  }

  @doc """
  Checks if the `promotion` is already applied to the order.

  Returns {:false, message} if promotion is already applied otherwise
  returns true.
  Tracks by checking if adjustments already exist for the order for the
  supplied `promotion`

  """
  def promotion_applied(order, promotion) do
    case PromotionAdjustment.order_adjustments_for_promotion(order, promotion) do
      [] ->
        {true, @message.applicable}

      _list ->
        {false, @coupon_applied}
    end
  end

  @doc """
  Checks the state of the order before applying the promotion.

  At present the supported states are `[:address, :delivery]`

  Returns {false, message} if order not in valid state otherwise,
  returns true.
  """
  def valid_order_state(order) do
    if order.state in @valid_order_states do
      {true, @message.valid_state}
    else
      {false, "promotion not applicable to order"}
    end
  end

  @doc """
  Checks if an order is `promotionable`.

  An order is considered `promotionable` if it contains atlease one `promotionable`
  product as lineitem. If no `promotionable` products are found the order is
  ineligible for promotion.
  Returns `true` if promotionable otherwise, returns {false, message}
  """
  def order_promotionable(order) do
    order = Repo.preload(order, line_items: [:product])

    if Enum.any?(order.line_items, fn line_item ->
         line_item.product.promotionable == true
       end) do
      {true, @message.promotionable}
    else
      {false, "no promotionable products found"}
    end
  end

  @doc """
  Checks the order against the rules defined for the promotion.

  The rules are checked as per the match policy defined in the supplied
  promotion.
  A match policy of type "all" checks that all the rules should
  be satisfied to apply the promotion.
  A match policy of type "any" checks that any one of the rules
  should be satisfied to apply the promotions.

  Returns true if the rule_check is satisfied else returns {false, message}
  where message is set by first non-applicable rule.
  """
  def rules_check(order, promotion) do
    promotion = Repo.preload(promotion, :rules)

    case check_eligibility(promotion.match_policy, order, promotion.rules) do
      {true, _success_message} = reason ->
        reason

      {false, _message} = reason ->
        reason
    end
  end

  defp check_eligibility(_, _order, _no_rules_set = []) do
    {true, @success_message}
  end

  defp check_eligibility("all", order, rules) do
    Enum.reduce_while(rules, {true, @success_message}, fn rule, acc ->
      case rule_eligibility(order, rule) do
        {true, _} ->
          {:cont, acc}

        {false, _reason} = error ->
          acc = error
          {:halt, acc}
      end
    end)
  end

  defp check_eligibility("any", order, rules) do
    Enum.reduce_while(rules, {false, @error_message}, fn rule, _ ->
      case rule_eligibility(order, rule) do
        {false, _reason} = reason ->
          acc = reason
          {:cont, acc}

        {true, _reason} = reason ->
          acc = reason
          {:halt, acc}
      end
    end)
  end

  defp rule_eligibility(order, rule) do
    rule.module.eligible(order, rule.preferences)
  end
end
