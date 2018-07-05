defmodule Snitch.Data.Model.VariantTest do
  use ExUnit.Case, async: true
  use Snitch.DataCase

  import Snitch.Factory

  alias Snitch.Data.Model.Variant

  test "get_category/1" do
    v = insert(:variant, shipping_category: build(:shipping_category))
    assert v.shipping_category == Variant.get_category(v)
  end

  describe "get_selling_prices/1" do
    setup :variants

    test "with valid and invalid ids", %{variants: vs} do
      ids = Enum.map(vs, fn %{id: id} -> id end)

      prices = Variant.get_selling_prices([-1 | ids])

      assert Enum.into(prices, %{}, fn {v_id, money} ->
               {v_id, Money.reduce(money)}
             end) ==
               Enum.into(vs, %{}, fn %{id: id, selling_price: sp} ->
                 {id, sp}
               end)
    end

    test "with empty list" do
      assert %{} == Variant.get_selling_prices([])
    end
  end
end
