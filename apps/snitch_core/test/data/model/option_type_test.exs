defmodule Snitch.Data.Model.OptionTest do
  use ExUnit.Case, async: true
  use Snitch.DataCase

  import Snitch.Factory

  alias Snitch.Data.Model.Option, as: OptionModel
  alias Snitch.Data.Model.Product, as: ProductModel
  alias Snitch.Data.Model.VariationTheme, as: VTModel
  alias Snitch.Data.Schema.{Product, Option, VariationTheme}
  alias Snitch.Repo

  setup do
    option_type = insert(:option_type)
    shipping_category = insert(:shipping_category)

    {:ok, theme} =
      %{
        "name" => "ThemeXYZ",
        "option_type_ids" => [to_string(option_type.id)]
      }
      |> VTModel.create()

    taxon = insert(:taxon)
    tax_class = insert(:tax_class)

    params = %{
      "name" => "ProductXYZ",
      "selling_price" => Money.new("12.99", currency()),
      "max_retail_price" => Money.new("14.99", currency()),
      "taxon_id" => taxon.id,
      "shipping_category_id" => shipping_category.id,
      "tax_class_id" => tax_class.id
    }

    {:ok, product} = ProductModel.create(params)
    product = Product.associate_theme_changeset(product, %{theme_id: theme.id}) |> Repo.update!()

    [option_type: option_type]
  end

  describe "option type association" do
    test "if it's associated with a product's theme", %{option_type: option_type} do
      assert OptionModel.is_theme_associated(option_type.id) == true
    end

    test "if it's not associated with any product's theme" do
      option_type = insert(:option_type)
      assert OptionModel.is_theme_associated(option_type.id) == false
    end
  end
end
