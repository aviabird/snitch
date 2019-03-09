defmodule Snitch.Data.Model.Promotion do
  @moduledoc """
  APIs for promotion.
  """
  use Snitch.Data.Model
  alias Snitch.Data.Model.Promotion.{Applicability, Eligibility}
  alias Snitch.Data.Model.PromotionAdjustment
  alias Snitch.Data.Schema.Promotion

  @messages %{
    coupon_applied: "promotion applied",
    failed: "promotion activation failed"
  }

  @doc """
  Creates a promotion with the supplied params.

  The params can have a list of `rules` provided under the rules key
  as well as `actions` under the key actions.

  The `rules` and `actions` are casted with the promotion.

  ## See also
  `Ecto.Changeset.cast_assoc/3`
  """
  @spec create(map) :: {:ok, Promotion.t()} | {:error, Ecto.Changeset.t()}
  def create(params) do
    QH.create(Promotion, params, Repo)
  end

  @doc """
  Updates the `promotion` with supplied `params`.

  Before updating an action it is verified if it is archived or
  ongoing. In case the promotion has started(ongoing) it can not be updated.
  An archived promotion can also not be updated.
  """
  @spec update(Package.t(), map) ::
          {:ok, Ecto.Schema.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, String.t()}
  def update(promotion, params) do
    with {false, _message} <- archived(promotion),
         {false, _message} <- ongoing(promotion) do
      promotion = Repo.preload(promotion, [:actions, :rules])
      QH.update(Promotion, params, promotion, Repo)
    else
      {true, message} ->
        {:error, message}
    end
  end

  @doc """
  Checks if the promotion is `archived`.

  Returns `{true, message}` or `{false, message}` based on whether it is archived
  or not.
  """
  def archived(promotion) do
    if promotion.archived_at == 0 do
      {false, "promotion is active"}
    else
      {true, "promotion no longer active"}
    end
  end

  @doc """
  Checks if the promotion is ongoing.

  Returns `{true, message}` or `{false, message}` based on whether it is archived
  or not.
  """
  def ongoing(promotion) do
    active = promotion.active?

    date_check =
      DateTime.compare(promotion.starts_at, DateTime.utc_now()) == :lt and
        DateTime.compare(promotion.expires_at, DateTime.utc_now()) == :gt

    if active && date_check && has_adjustments?(promotion) do
      {true, "promotion ongoing"}
    else
      {false, "promotion not active"}
    end
  end

  @doc """
  Arhcives a promotion.

  An archived promotion can not be used for any order. Also, it can not
  be updated. It is mainly for keeping a track of the adjustments created
  for the promotion.
  """
  @spec update(Package.t(), map) ::
          {:ok, Promotion.t()}
          | {:error, Ecto.Changeset.t()}
  def archive(promotion) do
    params = %{archived_at: DateTime.to_unix(DateTime.utc_now())}
    QH.update(Promotion, params, promotion, Repo)
  end

  @spec get(map) :: {:ok, Promotion.t()} | {:error, atom}
  def get(query_fields) do
    case Promotion |> QH.get(query_fields, Repo) do
      {:ok, promotion} ->
        promotion = promotion |> Repo.preload([:actions, :rules])
        {:ok, promotion}

      {:error, msg} ->
        {:error, msg}
    end
  end

  @doc """
  Returns a list of promotions.

  Returns only those promotions which are not archived.
  """
  def get_all() do
    date_time = 0
    query = from(p in Promotion, where: p.archived_at == ^date_time)
    Repo.all(query)
  end

  @doc """
  Applies a coupon to the supplied order depending on some
  conditions.

  Returns {:ok, map} | {:error, map} depending on whether the coupon was
  applied or not.

  ### Note
  At present adjustments can happen for only one valid coupon at a time, multiple
  coupon application is not supported.
  """
  @spec apply(order :: Order.t(), coupon :: String.t()) ::
          {:ok, map}
          | {:error, map}
  def apply(order, coupon) do
    with {:ok, promotion} <- Applicability.valid_coupon_check(coupon),
         {:ok, _message} <- Eligibility.eligible(order, promotion) do
      if activate?(order, promotion) do
        process_adjustments(order, promotion)
      end
    else
      {:error, _message} = reason ->
        reason
    end
  end

  @doc """
  Applies actions for a promotion on an order.

  Returns true if promotion actions are applied otherwise, returns false.
  """
  def activate?(order, promotion) do
    promotion = Repo.preload(promotion, :actions)

    promotion.actions
    |> Enum.map(fn action ->
      action.module.perform?(order, promotion, action)
    end)
    |> Enum.any?(fn item -> item == true end)
  end

  @doc """
  Returns whether the supplied `line item` can be activated or not
  by the promotion line_item related action.

  The line_item is evaluated against promotion rules which contain
  data that affects a line_item.

  In case no rules are set for the promotion `true` is returned for the
  supplied `line_item`.
  """
  @spec line_item_actionable?(line_item :: LineItem.t(), Promotion.t()) :: boolean()
  def line_item_actionable?(line_item, %Promotion{match_policy: "all"} = promotion) do
    promotion = Repo.preload(promotion, :rules)

    Enum.all?(promotion.rules, fn rule ->
      rule.module.line_item_actionable?(line_item, rule)
    end)
  end

  def line_item_actionable?(line_item, %Promotion{match_policy: "any"} = promotion) do
    promotion = Repo.preload(promotion, :rules)

    if promotion.rules == [] do
      true
    else
      Enum.any?(promotion.rules, fn rule ->
        rule.module.line_item_actionable?(line_item, rule)
      end)
    end
  end

  def update_usage_count(promotion, count) do
    current_usage_count = promotion.current_usage_count
    params = %{current_usage_count: current_usage_count + count}

    QH.update(Promotion, params, promotion, Repo)
  end

  ############################## private functions ####################

  defp has_adjustments?(promotion) do
    case PromotionAdjustment.promotion_adjustments(promotion) do
      [] ->
        false

      _list ->
        true
    end
  end

  defp process_adjustments(order, promotion) do
    case PromotionAdjustment.process_adjustments(order, promotion) do
      {:ok, _data} ->
        update_usage_count(promotion, 1)
        {:ok, @messages.coupon_applied}

      {:error, _message} = error ->
        error
    end
  end
end
