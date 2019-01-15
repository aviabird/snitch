defmodule Snitch.Data.Schema.Product do
  @moduledoc """
  Models a Product.
  """

  use Snitch.Data.Schema
  use Rummage.Ecto

  import Ecto.Query

  alias Snitch.Data.Model.Product, as: ProductModel
  alias Snitch.Data.Schema.Product.NameSlug
  alias Snitch.Domain.Taxonomy

  alias Snitch.Data.Schema.{
    Variation,
    Image,
    ProductOptionValue,
    VariationTheme,
    Review,
    ProductBrand,
    StockItem,
    ShippingCategory,
    Taxon
  }

  alias Money.Ecto.Composite.Type, as: MoneyType

  @type t :: %__MODULE__{}

  schema "snitch_products" do
    field(:name, :string, null: false, default: "")
    field(:description, :string)
    field(:available_on, :utc_datetime)
    field(:deleted_at, :utc_datetime)
    field(:discontinue_on, :utc_datetime)
    field(:slug, :string)

    # unique product number(upn) to indentify a product uniquely
    # just like amazon uses asin (Amazon Standard Identification Number)
    # for unique identification of products.
    field(:upn, :string, autogenerate: {ProductModel, :upn_generate, []})

    field(:meta_description, :string)
    field(:meta_keywords, :string)
    field(:meta_title, :string)
    field(:promotionable, :boolean)
    field(:selling_price, MoneyType)
    field(:max_retail_price, MoneyType)
    field(:height, :decimal, default: Decimal.new(0))
    field(:width, :decimal, default: Decimal.new(0))
    field(:depth, :decimal, default: Decimal.new(0))
    field(:sku, :string)
    field(:position, :integer)
    field(:weight, :decimal, default: Decimal.new(0))
    field(:is_active, :boolean, default: true)

    # Track tenant name during elasticsearch
    # multitenant query on all schemas at once
    field(:tenant, :string, virtual: true)

    field(:state, ProductStateEnum, default: :draft)
    field(:inventory_tracking, InventoryTrackingEnum, default: :none)

    # Following fields are used in context of import
    field(:store, :string, default: "avia")
    field(:import_product_id, :string)

    timestamps()

    has_many(:variations, Variation, foreign_key: :parent_product_id, on_replace: :delete)
    has_many(:variants, through: [:variations, :child_product])

    has_one(:parent_variation, Variation, foreign_key: :child_product_id)

    many_to_many(
      :products,
      Snitch.Data.Schema.Product,
      join_through: "snitch_product_variants",
      join_keys: [parent_product_id: :id, child_product_id: :id]
    )

    has_many(:options, ProductOptionValue)
    has_many(:stock_items, StockItem)

    many_to_many(:reviews, Review, join_through: "snitch_product_reviews")
    many_to_many(:images, Image, join_through: "snitch_product_images", on_replace: :delete)

    belongs_to(:theme, VariationTheme)
    belongs_to(:brand, ProductBrand)
    belongs_to(:shipping_category, ShippingCategory)
    belongs_to(:taxon, Taxon)
  end

  @required_fields ~w(name selling_price max_retail_price taxon_id shipping_category_id)a
  @optional_fields ~w(description meta_description meta_keywords meta_title brand_id height width depth weight state inventory_tracking)a

  def create_changeset(model, params \\ %{}) do
    common_changeset(model, params)
  end

  def update_changeset(model, params \\ %{}) do
    model
    |> common_changeset(params)
    |> cast_assoc(:images, with: &Image.changeset/2)
  end

  def associate_image_changeset(product, images) do
    product = Repo.preload(product, [:images])

    product
    |> change
    |> put_assoc(:images, images)
  end

  def associate_theme_changeset(product, params) do
    product
    |> change
    |> put_change(:theme_id, params.theme_id)
  end

  def variant_create_changeset(parent_product, params) do
    parent_product
    |> Repo.preload([:variants, :options])
    |> cast(params, [:theme_id])
    |> validate_required([:theme_id])
    |> cast_assoc(:variations, required: true)
    |> theme_change_check()
  end

  def delete_changeset(product, _params \\ %{}) do
    product = Repo.preload(product, [:products])

    variant_params =
      product.products
      |> Enum.map(
        &%{"state" => "deleted", "id" => &1.id, "deleted_at" => NaiveDateTime.utc_now()}
      )

    params = %{
      "id" => product.id,
      "state" => "deleted",
      "products" => variant_params,
      "deleted_at" => NaiveDateTime.utc_now()
    }

    product
    |> cast(params, [:state, :deleted_at])
    |> cast_assoc(:products, with: &cast(&1, &2, [:state, :deleted_at]))
  end

  def child_product(model, params \\ %{}) do
    model
    |> common_changeset(params)
    |> cast_assoc(:options)
  end

  defp common_changeset(model, params) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_amount(:selling_price)
    |> NameSlug.maybe_generate_slug()
    |> unique_constraint(:upn, message: "Ooops, another product already has that name!")
  end

  def product_by_category_query(taxon_id) do
    {:ok, categories} = Taxonomy.get_all_children_and_self(taxon_id)

    categories_ids = Enum.map(categories, & &1.id)

    from(p in __MODULE__, where: p.taxon_id in ^categories_ids)
  end

  def set_delete_fields(%Ecto.Query{} = product_query) do
    from(p in product_query,
      update: [set: [state: "deleted", deleted_at: ^NaiveDateTime.utc_now(), taxon_id: nil]]
    )
  end

  defp theme_change_check(changeset) do
    case get_change(changeset, :theme_id) do
      nil -> handle_variant_replace(changeset)
      _ -> changeset
    end
  end

  def handle_variant_replace(changeset) do
    variant_changes =
      get_change(changeset, :variations)
      |> Enum.map(fn c ->
        if c.action == :replace do
          Map.update(c, :action, nil, fn x -> nil end)
        else
          c
        end
      end)

    put_change(changeset, :variations, variant_changes)
  end

  def is_variant_tracking_enabled?(product) do
    product.inventory_tracking == :variant
  end
end

defmodule Snitch.Data.Schema.Product.NameSlug do
  @moduledoc false

  use EctoAutoslugField.Slug, from: :name, to: :slug
end
