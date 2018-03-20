defmodule Snitch.Data.Model.ShipmentUnitModelTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use Snitch.DataCase
  import Snitch.Factory
  alias Snitch.Data.Model.ShipmentUnit, as: ShipmentUnitModel

  setup do
    [variant: insert(:variant)]
  end

  describe "create/4" do
    test "Fails for INVALID stock item id" do
      assert {:error, changeset} = ShipmentUnitModel.create(1, 1)
      refute changeset.valid?
      assert %{stock_item_id: ["does not exist"]} = errors_on(changeset)
    end

    test "Fails with invalid quantity", context do
      %{stock_item: stock_item} = context
      assert {:error, changeset} = ShipmentUnitModel.create("abc", stock_item.id)
      assert [quantity: {"is invalid", [type: :integer, validation: :cast]}] = changeset
    end

    test "Inserts with valid attributes", context do
      %{stock_item: stock_item} = context
      assert {:ok, stock_movement} = ShipmentUnitModel.create(1, stock_item.id)
      assert stock_movement.stock_item_id == stock_item.id
    end
  end

  describe "get/1" do
    test "Fails with invalid id" do
      stock_item = ShipmentUnitModel.get(1)
      assert nil == stock_item
    end

    test "gets with valid id", context do
      %{stock_item: stock_item} = context
      insert_stock_movement = insert(:stock_movement, stock_item: stock_item)

      get_stock_movement = ShipmentUnitModel.get(insert_stock_movement.id)
      assert insert_stock_movement.id == get_stock_movement.id
      assert insert_stock_movement.stock_item_id == stock_item.id
      assert insert_stock_movement.quantity == get_stock_movement.quantity
      assert insert_stock_movement.action == get_stock_movement.action
      assert insert_stock_movement.originator_type == get_stock_movement.originator_type
      assert insert_stock_movement.originator_id == get_stock_movement.originator_id

      # with stock item map
      get_stock_movement_with_map = ShipmentUnitModel.get(%{id: insert_stock_movement.id})
      assert insert_stock_movement.id == get_stock_movement_with_map.id
      assert insert_stock_movement.stock_item_id == stock_item.id
      assert insert_stock_movement.quantity == get_stock_movement_with_map.quantity
      assert insert_stock_movement.action == get_stock_movement_with_map.action
      assert insert_stock_movement.originator_type == get_stock_movement_with_map.originator_type
      assert insert_stock_movement.originator_id == get_stock_movement_with_map.originator_id
    end
  end

  describe "get_all/0" do
    test "fetches all the stock items" do
      stock_movements = ShipmentUnitModel.get_all()
      assert 0 = Enum.count(stock_movements)

      # add for multiple random stock items
      insert_list(1, :stock_movement)
      insert_list(2, :stock_movement)

      stock_movements_new = ShipmentUnitModel.get_all()
      assert 3 = Enum.count(stock_movements_new)
    end
  end
end
