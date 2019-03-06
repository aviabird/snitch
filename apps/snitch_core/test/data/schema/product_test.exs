defmodule Snitch.Data.Schema.ProductTest do
  use ExUnit.Case, async: true
  use Snitch.DataCase

  alias Snitch.Core.Tools.MultiTenancy.Repo
  alias Snitch.Data.Schema.Product
  import Snitch.Factory

  test "test valid data create_changeset/2" do
    taxon = insert(:taxon)
    shipping_category = insert(:shipping_category)
    tax_class = insert(:tax_class)

    params = %{
      name: "HTC Desire 620",
      description: "HTC desire 620",
      selling_price: Money.new("12.99", currency()),
      max_retail_price: Money.new("14.99", currency()),
      taxon_id: taxon.id,
      shipping_category_id: shipping_category.id,
      tax_class_id: tax_class.id
    }

    changeset = Product.create_changeset(%Product{}, params)

    assert changeset.valid?
    assert changeset.changes.slug == "htc-desire-620"
    assert {:ok, _product} = Repo.insert(changeset)
  end

  test "create_changeset/2 fails for duplicate slug" do
    taxon = insert(:taxon)
    shipping_category = insert(:shipping_category)
    tax_class = insert(:tax_class)

    params = %{
      name: "HTC Desire 620",
      description: "HTC desire 620",
      selling_price: Money.new("12.99", currency()),
      max_retail_price: Money.new("14.99", currency()),
      taxon_id: taxon.id,
      shipping_category_id: shipping_category.id,
      tax_class_id: tax_class.id
    }

    changeset = Product.create_changeset(%Product{}, params)
    {:ok, _} = Repo.insert(changeset)
    cs = Product.create_changeset(%Product{}, params)
    {:error, changeset} = Repo.insert(cs)
    assert %{name: ["unique name for products"]} == errors_on(changeset)
  end

  test "test invalid data for create_changeset/2" do
    params = %{
      description: "HTC desire 620"
    }

    changeset = Product.create_changeset(%Product{}, params)

    refute changeset.valid?
    assert changeset.errors[:name] == {"can't be blank", [validation: :required]}
  end

  test "test valid data for variant_create_changeset/2" do
    parent_product = insert(:product)
    theme = insert(:variation_theme)
    [ot1, ot2] = insert_list(2, :option_type)
    taxon = insert(:taxon)

    params = %{
      "theme_id" => theme.id,
      "variations" => [
        %{
          "child_product" => %{
            "name" => "Child Product 1",
            "options" => [
              %{"option_id" => ot1.id, "value" => "red"},
              %{"option_id" => ot2.id, "value" => "S"}
            ],
            "selling_price" => Money.new("12.99", currency()),
            "max_retail_price" => Money.new("14.99", currency()),
            "taxon_id" => taxon.id,
            "shipping_category_id" => parent_product.shipping_category_id
          }
        },
        %{
          "child_product" => %{
            "name" => "Child Product 2",
            "options" => [
              %{"option_id" => ot1.id, "value" => "yellow"},
              %{"option_id" => ot2.id, "value" => "S"}
            ],
            "selling_price" => Money.new("12.99", currency()),
            "max_retail_price" => Money.new("14.99", currency()),
            "taxon_id" => taxon.id,
            "shipping_category_id" => parent_product.shipping_category_id
          }
        }
      ]
    }

    changeset = Product.variant_create_changeset(parent_product, params)

    assert changeset.valid?
    assert {:ok, product} = Repo.update(changeset)
    assert product.theme_id == theme.id
  end

  test "test new variant addition using variant_create_changeset/2" do
    parent_product = insert(:product)
    theme = insert(:variation_theme)
    [ot1, ot2] = insert_list(2, :option_type)
    taxon = insert(:taxon)

    params = %{
      "theme_id" => theme.id,
      "variations" => [
        %{
          "child_product" => %{
            "name" => "Child Product 1",
            "options" => [
              %{"option_id" => ot1.id, "value" => "red"},
              %{"option_id" => ot2.id, "value" => "S"}
            ],
            "selling_price" => Money.new("12.99", currency()),
            "max_retail_price" => Money.new("14.99", currency()),
            "taxon_id" => taxon.id,
            "shipping_category_id" => parent_product.shipping_category_id
          }
        },
        %{
          "child_product" => %{
            "name" => "Child Product 2",
            "options" => [
              %{"option_id" => ot1.id, "value" => "yellow"},
              %{"option_id" => ot2.id, "value" => "S"}
            ],
            "selling_price" => Money.new("12.99", currency()),
            "max_retail_price" => Money.new("14.99", currency()),
            "taxon_id" => taxon.id,
            "shipping_category_id" => parent_product.shipping_category_id
          }
        }
      ]
    }

    changeset = Product.variant_create_changeset(parent_product, params)
    {:ok, product} = Repo.update(changeset)

    params = %{
      "id" => product.id,
      "variations" => [
        %{
          "child_product" => %{
            "name" => "Child Product 3",
            "options" => [
              %{"option_id" => ot1.id, "value" => "blue"},
              %{"option_id" => ot2.id, "value" => "S"}
            ],
            "selling_price" => Money.new("12.99", currency()),
            "max_retail_price" => Money.new("14.99", currency()),
            "taxon_id" => taxon.id,
            "shipping_category_id" => parent_product.shipping_category_id
          }
        }
      ]
    }

    changeset = Product.variant_create_changeset(product, params)
    {:ok, product} = Repo.update(changeset)
    product = product |> Repo.preload(:variants)

    assert product.variants |> length == 3
  end

  test "add variant and change theme using variant_create_changeset/2" do
    parent_product = insert(:product)
    theme = insert(:variation_theme)
    [ot1, ot2] = insert_list(2, :option_type)
    taxon = insert(:taxon)

    params = %{
      "theme_id" => theme.id,
      "variations" => [
        %{
          "child_product" => %{
            "name" => "Child Product 1",
            "options" => [
              %{"option_id" => ot1.id, "value" => "red"},
              %{"option_id" => ot2.id, "value" => "S"}
            ],
            "selling_price" => Money.new("12.99", currency()),
            "max_retail_price" => Money.new("14.99", currency()),
            "taxon_id" => taxon.id,
            "shipping_category_id" => parent_product.shipping_category_id
          }
        },
        %{
          "child_product" => %{
            "name" => "Child Product 2",
            "options" => [
              %{"option_id" => ot1.id, "value" => "yellow"},
              %{"option_id" => ot2.id, "value" => "S"}
            ],
            "selling_price" => Money.new("12.99", currency()),
            "max_retail_price" => Money.new("14.99", currency()),
            "taxon_id" => taxon.id,
            "shipping_category_id" => parent_product.shipping_category_id
          }
        }
      ]
    }

    changeset = Product.variant_create_changeset(parent_product, params)
    {:ok, product} = Repo.update(changeset)

    new_theme = insert(:variation_theme)

    params = %{
      "theme_id" => new_theme.id,
      "id" => product.id,
      "variations" => [
        %{
          "child_product" => %{
            "name" => "Child Product 3",
            "options" => [
              %{"option_id" => ot1.id, "value" => "blue"},
              %{"option_id" => ot2.id, "value" => "S"}
            ],
            "selling_price" => Money.new("12.99", currency()),
            "max_retail_price" => Money.new("14.99", currency()),
            "taxon_id" => taxon.id,
            "shipping_category_id" => parent_product.shipping_category_id
          }
        }
      ]
    }

    changeset = Product.variant_create_changeset(product, params)

    {:ok, product} = Repo.update(changeset)
    product = product |> Repo.preload(:variants)

    assert product.variants |> length == 1
  end
end
