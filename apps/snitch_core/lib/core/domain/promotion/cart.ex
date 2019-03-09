defmodule Snitch.Domain.Promotion.CartHelper do
  @moduledoc """
  Module exposes functions to handle promotion related checks on
  an order.

  If an order has any promotion associated with it then, on addition, updation
  or removal of lineitem it may become eligible or ineligible for the promotion.
  """

  import Ecto.Query
  alias Ecto.Multi
  alias Snitch.Core.Tools.MultiTenancy.Repo
  alias Snitch.Data.Schema.{Adjustment, Promotion, PromotionAdjustment}
  alias Snitch.Data.Model.Promotion.Eligibility
  alias Snitch.Data.Model.Promotion, as: PromotionModel
  alias Snitch.Data.Model.PromotionAdjustment, as: PromoAdjModel
  alias Snitch.Data.Model.Promotion.OrderEligibility

  @success_message "coupon applied"
  @failure_message "promotion not applicable"

  @doc """
  Revaluates the promotion for order for which the line_item was
  touched(created, updated or removed).

  Finds out the `promotion` for which the `order` has active promotios.

  > Active promotions for an order is found out by checking if `eligible` promotion related
  > adjustments are present for the order.
  > See Snitch.Data.Model.PromotionAdjustment
  """
  @spec evaluate_promotion(Order.t()) :: {:ok, map} | {:error, String.t()}
  def evaluate_promotion(order) do
    case get_promotion(order) do
      nil ->
        {:error, "no promotion applied to order"}

      promotion ->
        process_adjustments(order, promotion)
    end
  end

  # Handles adjustments for the promotion returned for the order. If the order
  # becomes ineligible for the promotion then removes all the records for the order
  # and the promotion. In case order is still eligible for promotion new adjustments
  # as line item has modified the order and promotion actions will act differently
  # on the modified order. The older adjustments existing for the order are removed.
  defp process_adjustments(order, promotion) do
    with {:ok, _message} <- eligibility_checks(order, promotion) do
      if PromotionModel.activate?(order, promotion) do
        activate_recent_adjustments(order, promotion)
      end
    else
      {:error, _message} ->
        remove_adjustments(order, promotion)
    end
  end

  defp remove_adjustments(order, promotion) do
    Multi.new()
    |> Multi.delete_all(
      :remove_adjustments_for_promotion,
      from(
        adj in Adjustment,
        join: p_adj in PromotionAdjustment,
        on: p_adj.adjustment_id == adj.id,
        where: p_adj.order_id == ^order.id and p_adj.promotion_id == ^promotion.id
      )
    )
    |> Multi.run(:update_promotion_count, fn _ ->
      PromotionModel.update_usage_count(promotion, -1)
    end)
    |> persist()
  end

  defp activate_recent_adjustments(order, promotion) do
    adjustments = PromoAdjModel.order_adjustments_for_promotion(order, promotion)

    old_adjustment_ids =
      Enum.flat_map(adjustments, fn adj ->
        if adj.eligible == true, do: [adj.id], else: []
      end)

    new_adjustment_ids =
      Enum.flat_map(adjustments, fn adj ->
        if adj.eligible == false, do: [adj.id], else: []
      end)

    Multi.new()
    |> Multi.delete_all(
      :remove_old_adjustments,
      from(adj in Adjustment, where: adj.id in ^old_adjustment_ids)
    )
    |> Multi.update_all(
      :mark_new_adjustment_as_eligible,
      from(adj in Adjustment, where: adj.id in ^new_adjustment_ids),
      set: [eligible: true]
    )
    |> persist()
  end

  defp get_promotion(order) do
    case get_active_promotion_id(order) do
      nil ->
        nil

      id ->
        Repo.get(Promotion, id)
    end
  end

  defp get_active_promotion_id(order) do
    query =
      from(adj in Adjustment,
        join: p_adj in PromotionAdjustment,
        on: adj.id == p_adj.adjustment_id,
        where: p_adj.order_id == ^order.id and adj.eligible == true,
        limit: 1,
        select: p_adj.promotion_id
      )

    Repo.one(query)
  end

  # Run the accumulated multi struct
  defp persist(multi) do
    case Repo.transaction(multi) do
      {:ok, data} ->
        {:ok, data}

      {:error, _, data, _} ->
        {:error, data}
    end
  end

  defp eligibility_checks(order, promotion) do
    with true <- Eligibility.promotion_level_check(promotion),
         {true, _message} <- OrderEligibility.order_promotionable(order),
         {true, _message} <- OrderEligibility.rules_check(order, promotion) do
      {:ok, @success_message}
    else
      {false, message} ->
        {:error, message}

      false ->
        {:error, @failure_message}
    end
  end
end
