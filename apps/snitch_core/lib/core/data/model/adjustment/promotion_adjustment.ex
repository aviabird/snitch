defmodule Snitch.Data.Model.PromotionAdjustment do
  @moduledoc """
  Exposes functions related to adjustments created for
  promotions.
  """

  use Snitch.Data.Model
  alias Ecto.Multi
  alias Snitch.Data.Model.Adjustment
  alias Snitch.Data.Schema.PromotionAdjustment
  alias Snitch.Data.Schema.Adjustment, as: AdjustmentSchema

  @messages %{
    adjustments_failed: "promotion adjustment update failed",
    better_coupon_present: "better promotion already exists"
  }

  @doc """
  Creates a promotion adjustment.

  The function creates an `adjustment` record alongwith the `promotion adjustment`.
  ### See
  `Snitch.Data.Schema.Adjustment`

  The function expects following keys in the `params`
    - `:order`
    - `:promotion`
    - `:promotion_action`
    - `:adjustable_type`
    - `:adjustable_id`
    - `:amount`

  ### Note
    All the above mentioned keys are mandatory for creating an adjustment.
  """
  @spec create(map) :: {:ok, PromotionAdjustment.t()} | {:error, Ecto.Changeset.t()}
  def create(params) do
    Multi.new()
    |> Multi.run(:adjustment, fn _ ->
      params = set_adjustment_params(params)
      Adjustment.create(params)
    end)
    |> Multi.run(:promo_adj, fn %{adjustment: adjustment} ->
      params = set_promo_adjustment_params(params, adjustment)
      QH.create(PromotionAdjustment, params, Repo)
    end)
    |> persist()
  end

  def order_adjustments(order) do
    query =
      from(adj in AdjustmentSchema,
        join: p_adj in PromotionAdjustment,
        on: adj.id == p_adj.adjustment_id,
        where: p_adj.order_id == ^order.id,
        select: adj
      )

    Repo.all(query)
  end

  @doc """
  Returns all adjustments for the supplied `order` and `promotion`.
  """
  def order_adjustments_for_promotion(order, promotion) do
    query =
      from(adj in AdjustmentSchema,
        join: p_adj in PromotionAdjustment,
        on: adj.id == p_adj.adjustment_id,
        where: p_adj.order_id == ^order.id and p_adj.promotion_id == ^promotion.id,
        select: adj
      )

    Repo.all(query)
  end

  def eligible_order_adjustments(order) do
    query =
      from(adj in AdjustmentSchema,
        join: p_adj in PromotionAdjustment,
        on: adj.id == p_adj.adjustment_id,
        where: p_adj.order_id == ^order.id and adj.eligible == true,
        select: adj
      )

    Repo.all(query)
  end

  def promotion_adjustments(promotion) do
    query =
      from(adj in AdjustmentSchema,
        join: p_adj in PromotionAdjustment,
        on: adj.id == p_adj.adjustment_id,
        where: p_adj.promotion_id == ^promotion.id,
        select: adj
      )

    Repo.all(query)
  end

  @doc """
  Processes adjustments for the supplied `order` and `promotion`.

  Adjustments are created for all the `actions` of a `promotion`
  on an order. However, these adjustments are created in an ineligible state,
  handled by the `eligible` field in `Adjustments` which is initially false.

  The `eligible` field is marked true subject to condition that, a better promotion
  doesn't exist already for the order.
  In case a better promotion exists `{:error, message}` tuple is returned.
  Otherwise, the adjustments due to previous promotion are marked as ineligible
  by updating `eligible` field to false. And the `eligible` for adjustments
  due to present promotion are marked as true.

  A better promotion is one which provides more discount to the customer.
  """

  def process_adjustments(order, promotion) do
    %{
      current_discount: current_discount,
      previous_discount: previous_discount,
      previous_eligible_adjustment_ids: prev_eligible_ids,
      current_adjustment_ids: current_adjustment_ids
    } = get_adjustment_manifest(order, promotion)

    if current_discount > previous_discount do
      case activate_adjustments(
             order,
             prev_eligible_ids,
             current_adjustment_ids
           ) do
        {:ok, _data} = result ->
          result

        {:error, _data} ->
          {:error, @messages.adjustments_failed}
      end
    else
      {:error, @messages.better_coupon_present}
    end
  end

  ################## private functions ################

  defp activate_adjustments(order, prev_eligible_ids, current_adjustment_ids) do
    Multi.new()
    |> Multi.run(:remove_previous_eligible_adjustments, fn _ ->
      {:ok, update_adjustments(prev_eligible_ids, false)}
    end)
    |> Multi.run(:activate_new_adjustments, fn _ ->
      {:ok, update_adjustments(current_adjustment_ids, true)}
    end)
    |> Multi.delete_all(
      :delete_ineligible_adjustments,
      from(
        adj in AdjustmentSchema,
        join: p_adj in PromotionAdjustment,
        on: p_adj.adjustment_id == adj.id,
        where: p_adj.order_id == ^order.id and adj.eligible == false
      )
    )
    |> Repo.transaction()
    |> case do
      {:ok, data} ->
        {:ok, data}

      {:error, _, data, _} ->
        {:error, data}
    end
  end

  defp update_adjustments(ids, eligible) do
    Repo.update_all(
      from(adj in AdjustmentSchema,
        where: adj.id in ^ids
      ),
      set: [eligible: eligible]
    )
  end

  defp set_promo_adjustment_params(params, adjustment) do
    %{
      order_id: params.order.id,
      promotion_action_id: params.promotion_action.id,
      promotion_id: params.promotion.id,
      adjustment_id: adjustment.id
    }
  end

  defp set_adjustment_params(params) do
    %{
      adjustable_type: params.adjustable_type,
      adjustable_id: params.adjustable_id,
      amount: params.amount,
      label: params.promotion.code <> "(#{params.amount})"
    }
  end

  defp get_adjustment_manifest(order, promotion) do
    current_adjustments = order_adjustments_for_promotion(order, promotion)

    current_discount =
      Enum.reduce(current_adjustments, Decimal.new(0), fn adjustment, acc ->
        adjustment.amount |> Decimal.mult(-1) |> Decimal.add(acc)
      end)

    previous_eligible_adjustments = eligible_order_adjustments(order)

    previous_discount =
      Enum.reduce(previous_eligible_adjustments, 0, fn adjustment, acc ->
        adjustment.amount |> Decimal.mult(-1) |> Decimal.add(acc)
      end)

    %{
      current_discount: current_discount,
      previous_discount: previous_discount,
      previous_eligible_adjustment_ids: get_adjustment_ids(previous_eligible_adjustments),
      current_adjustment_ids: get_adjustment_ids(current_adjustments)
    }
  end

  defp get_adjustment_ids(adjustments) do
    Enum.map(adjustments, fn adjustment ->
      adjustment.id
    end)
  end

  # Run the accumulated multi struct
  defp persist(multi) do
    case Repo.transaction(multi) do
      {:ok, %{adjustment: adjustment}} ->
        {:ok, adjustment}

      {:error, _, data, _} ->
        {:error, data}
    end
  end
end
