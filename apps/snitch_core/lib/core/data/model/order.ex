defmodule Snitch.Data.Model.Order do
  @moduledoc """
  Order API
  """
  use Snitch.Data.Model
  import Snitch.Tools.Helper.QueryFragment

  alias Snitch.Data.Schema.Order
  alias Snitch.Data.Model.LineItem, as: LineItemModel

  @order_states ["confirmed", "complete"]
  @non_complete_order_states ~w(cart address delivery payment)a

  @doc """
  Creates an order with supplied `params` and `line_items`.

  `params` is a map that is passed to the
  `Snitch.Data.Schema.Order.changeset/3`.

  > * `line_items` is not a list of `LineItem` schema structs, but just a list
  >   of maps with the keys `:variant_id` and `:quantity`.
  > * These `LineItem`s will be created (casted, to be precise) along with the
  >   `Order` in a DB transaction.

  ## Example
  ```
  line_items = [%{variant_id: 1, quantity: 42}, %{variant_id: 2, quantity: 42}]
  params = %{user_id: 1}
  {:ok, order} = Snitch.Data.Model.Order.create(params, line_items)
  ```

  ## See also
  `Ecto.Changeset.cast_assoc/3`
  """
  @spec create(map) :: {:ok, Order.t()} | {:error, Ecto.Changeset.t()}
  def create(params) do
    QH.create(Order, update_in(params, [:line_items], &update_line_item_costs/1), Repo)
  end

  def create_guest_order() do
    %Order{}
    |> Order.create_guest_changeset(%{})
    |> Repo.insert()
  end

  @doc """
  Returns an `order` struct for the supplied `user_id`.

  An existing `order` associated with the user present in "#{inspect(@non_complete_order_states)}"
  state is returned if found. If no order is present for the user
  in these states, a new order is created and returned.
  """
  @spec user_order(non_neg_integer) :: Order.t()
  def user_order(user_id) do
    query =
      from(
        order in Order,
        where: order.user_id == ^user_id and order.state in ^@non_complete_order_states
      )

    query
    |> Repo.all()
    |> case do
      [] ->
        %Order{}
        |> Order.create_guest_changeset(%{})
        |> Ecto.Changeset.put_change(:user_id, user_id)
        |> Repo.insert()

      [order | _] ->
        {:ok, order}
    end
  end

  @doc """
  Creates an order with supplied `params` and `line_items`.

  Suitable for creating orders for guest users. The `order.user_id` cannot be
  set using this function.

  > * `line_items` is not a list of `LineItem` schema structs, but just a list
  >   of maps with the keys `:variant_id` and `:quantity`.
  > * These `LineItem`s will be created (casted, to be precise) along with the
  >   `Order` in a DB transaction.

  ## Example
  ```
  line_items = [%{variant_id: 1, quantity: 42}, %{variant_id: 2, quantity: 42}]
  params = %{user_id: 1}
  {:ok, order} = Snitch.Data.Model.Order.create(params, line_items)
  ```

  ## See also
  `Ecto.Changeset.cast_assoc/3`
  """
  @spec create_for_guest(map) :: {:ok, Order.t()} | {:error, Ecto.Changeset.t()}
  def create_for_guest(params) do
    %Order{}
    |> Order.create_for_guest_changeset(params)
    |> Repo.insert()
  end

  @doc """
  Updates the order with supplied `params`. `params` can include "new"
  `line_items`.

  ## Caution!

  The `line_items` are "casted" with the order and if `params` does not include
  a `line_items`, then **all previous line-items will be deleted!**

  ### Retain previous `LineItem`s

  If you wish to retain the line-items, you must pass a list of maps with the
  line-item `:id`s, like so:

  ```
  order # this is the order you wish to update, and `:line_items` are preloaded
  line_items = Enum.reduce(order.line_items, [], fn x, acc ->
  [%{id: x.id} | acc]
  end)
  params = %{} # All changes except line-items
  all_params = Map.put(params, :line_items, line_items)

  Snitch.Data.Model.Order.update(all_params, order)
  ```

  ### Updating some of the `LineItem`s

  Just like `create/2`, `line_items` is a list of maps, passing `LineItem`
  schema structs instead would fail. Along with the line-item params
  (`:variant_id` and `:quantity`) just pass the line-item `:id`.

  Let's say we have an `order` with the following `LineItem`s:
  ```
  order.line_items
  #=> [
  ..>   %LineItem{id: 1, quantity: 1, variant_id: 1, ...},
  ..>   %LineItem{id: 2, quantity: 1, variant_id: 3, ...},
  ..>   %LineItem{id: 3, quantity: 1, variant_id: 2, ...}
  ..> ]
  ```

  And we wish to:
  1. update the first,
  2. retain the second,
  3. remove the third and,
  4. add a "new" LineItem

  ```
  line_items = [
  %{id: 1, quantity: 42},        # updates quantity of first
  %{id: 2}                       # retains second
  %{variant_id: 4, quantity: 42} # adds a new line-item (no `:id`)
  ]                                # since there is no mention of `id: 3`,
  # it gets removed!

  params = %{line_items: line_items}
  {:ok, updated_order} = Snitch.Data.Model.Order.update(params, order)
  ```

  Let's see what we got,
  ```
  updated_order.line_items
  #=> [
  ..>   %LineItem{id: 1, quantity: 42, variant_id: 1, ...},
  ..>   %LineItem{id: 2, quantity: 42, variant_id: 2, ...},
  ..>   %LineItem{id: 4, quantity: 42, variant_id: 4, ...}
  ..> ]
  ```

  ## See also
  `Ecto.Changeset.cast_assoc/3`
  """
  @spec update(map, Order.t()) :: {:ok, Order.t()} | {:error, Ecto.Changeset.t()}
  def update(params, order \\ nil) do
    QH.update(Order, update_in(params, [:line_items], &update_line_item_costs/1), order, Repo)
  end

  @doc """
  Updates the order with supplied `params`. Does not update line_items.
  """
  @spec partial_update(Order.t(), map) :: {:ok, Order.t()} | {:error, Ecto.Changeset.t()}
  def partial_update(order, params) do
    order
    |> Order.partial_update_changeset(params)
    |> Repo.update()
  end

  @spec delete(non_neg_integer | Order.t()) ::
          {:ok, Order.t()} | {:error, Ecto.Changeset.t()} | {:error, :not_found}
  def delete(id_or_instance) do
    QH.delete(Order, id_or_instance, Repo)
  end

  @spec get(map | non_neg_integer) :: {:ok, Order.t()} | {:error, atom}
  def get(query_fields_or_primary_key) do
    QH.get(Order, query_fields_or_primary_key, Repo)
  end

  @spec get_all() :: [Order.t()]
  def get_all, do: Repo.all(Order)

  @doc """
    Returns all Orders with the given list of entities preloaded
  """
  def get_all_with_preloads(preloads) do
    Repo.all(Order) |> Repo.preload(preloads)
  end

  @doc """
    Order related to user.
  """
  @spec user_orders(String.t()) :: [Order.t()]
  def user_orders(user_id) do
    query =
      from(
        u in Order,
        where: u.user_id == ^user_id
      )

    Repo.all(query)
  end

  defp update_line_item_costs(line_items) when is_list(line_items) do
    LineItemModel.update_unit_price(line_items)
  end

  def get_order_count_by_state(start_date, end_date) do
    Order
    |> where(
      [o],
      o.inserted_at >= ^start_date and o.inserted_at <= ^end_date and o.state in ^@order_states
    )
    |> group_by([o], o.state)
    |> order_by([o], asc: o.state)
    |> select([o], %{state: o.state, count: count(o.id)})
    |> Repo.all()
  end

  def get_order_count_by_date(start_date, end_date) do
    Order
    |> where([o], o.inserted_at >= ^start_date and o.inserted_at <= ^end_date)
    |> group_by([o], to_char(o.inserted_at, "YYYY-MM-DD"))
    |> select([o], %{date: to_char(o.inserted_at, "YYYY-MM-DD"), count: count(o.id)})
    |> Repo.all()
    |> Enum.sort_by(&{Map.get(&1, :date)})
  end
end
