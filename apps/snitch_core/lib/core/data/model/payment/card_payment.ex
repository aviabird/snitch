defmodule Snitch.Data.Model.CardPayment do
  @moduledoc """
  CardPayment API and utilities.

  `CardPayment` is a concrete payment subtype in Snitch. By `create/2`ing a
  CardPayment, the supertype Payment is automatically created in the same
  transaction.

  > For other supported payment sources, see
    `Snitch.Data.Schema.PaymentMethod`
  """
  use Snitch.Data.Model

  alias Snitch.Data.{Schema, Model}
  alias Schema.CardPayment
  alias Model.PaymentMethod
  alias Ecto.Multi

  @doc """
  Creates both `Payment` and `CardPayment` records in a transaction for Order
  represented by `order_id`.

  * `payment_params` are validated using
    `Snitch.Data.Schema.Payment.changeset/3` with the `:create` action and
    because `slug` and `order_id` are passed explicitly to this function,
    they'll be ignored if present in `payment_params`.
  * `card_params` are validated using
  `Snitch.Data.Schema.CardPayment.changeset/3` with the `:create` action.
  """
  @spec create(String.t(), non_neg_integer(), map, map) ::
          {:ok, %{card_payment: CardPayment.t(), payment: Schema.Payment.t()}}
          | {:error, Ecto.Changeset.t()}
  def create(slug, order_id, payment_params, card_params) do
    payment = struct(Schema.Payment, payment_params)
    card_method = PaymentMethod.get_card()

    more_payment_params = %{
      order_id: order_id,
      payment_type: "ccd",
      payment_method_id: card_method.id,
      slug: slug
    }

    payment_changeset = Schema.Payment.changeset(payment, more_payment_params, :create)

    Multi.new()
    |> Multi.insert(:payment, payment_changeset)
    |> Multi.run(:card_payment, fn %{payment: payment} ->
      all_card_params = Map.put(card_params, :payment_id, payment.id)
      QH.create(CardPayment, all_card_params, Repo)
    end)
    |> Repo.transaction()
  end

  @doc """
  Updates `CardPayment` and `Payment` together.

  Everything except the `:payment_type` and `amount` can be changed, because by
  changing the type, `CardPayment` will have to be deleted.

  * `card_params` are validated using `Schema.CardPayment.changeset/3` with the
    `:update` action.
  * `payment_params` are validated using `Schema.Payment.changeset/3` with the
    `:update` action.
  """
  @spec update(CardPayment.t(), map, map) ::
          {:ok, %{card_payment: CardPayment.t(), payment: Schema.Payment.t()}}
          | {:error, Ecto.Changeset.t()}
  def update(card_payment, card_params, payment_params) do
    card_payment_changeset = CardPayment.changeset(card_payment, card_params, :update)

    Multi.new()
    |> Multi.update(:card_payment, card_payment_changeset)
    |> Multi.run(:payment, fn _ ->
      Model.Payment.update(nil, Map.put(payment_params, :id, card_payment.payment_id))
    end)
    |> Repo.transaction()
  end

  @doc """
  Fetches the struct but does not preload `:payment` association.
  """
  @spec get(map | non_neg_integer) :: CardPayment.t() | nil
  def get(query_fields_or_primary_key) do
    QH.get(CardPayment, query_fields_or_primary_key, Repo)
  end

  @spec get_all() :: [CardPayment.t()]
  def get_all, do: Repo.all(CardPayment)

  @doc """
  Fetch the CardPayment identified by the `payment_id`.

  > Note that the `:payment` association is not loaded.
  """
  @spec from_payment(non_neg_integer) :: CardPayment.t()
  def from_payment(payment_id) do
    get(%{payment_id: payment_id})
  end
end
