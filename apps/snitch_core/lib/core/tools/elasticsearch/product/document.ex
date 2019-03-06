defimpl Elasticsearch.Document, for: Snitch.Data.Schema.Product do
  alias Snitch.Data.Model.ProductReview, as: PRModel
  alias Snitch.Data.Model.Image, as: ImageModel
  alias Snitch.Core.Tools.MultiTenancy.Repo

  def id(product), do: "#{product.tenant}_#{product.id}"
  def routing(_), do: false
  def type(_product), do: "product"

  def encode(product) do
    self_or_parent_product = parent_or_standalone_product(product)
    # Example => "Iphone 6s (Space Grey, 32GB, 2GB RAM)"
    product = append_option_value_in_name(product)

    %{
      name: product.name,
      suggest_keywords: suggest_keywords(product),
      slug: self_or_parent_product.slug,
      parent_id: self_or_parent_product.id,
      # description: product.description,
      selling_price: format_money(product.selling_price),
      max_retail_price: format_money(product.max_retail_price),
      rating_summary: avg_rating(self_or_parent_product),
      images: product_images(product),
      updated_at: product.updated_at,
      tenant: product.tenant,
      string_facet: generate_string_facet(product, self_or_parent_product),
      number_facet: generate_number_facet(product, self_or_parent_product),
      category: gen_category_info(product.taxon)
      # meta_keywords: product.meta_keywords,
    }
  end

  defp parent_or_standalone_product(%{parent_variation: nil} = product), do: product
  defp parent_or_standalone_product(product), do: product.parent_variation.parent_product

  defp append_option_value_in_name(%{options: []} = product), do: product

  defp append_option_value_in_name(%{options: options} = product) do
    postfix =
      options
      |> Enum.map(&String.capitalize(&1.value))
      |> Enum.join(",")

    %{product | name: product.name <> " (" <> postfix <> ")"}
  end

  defp generate_string_facet(product, self_or_parent_product) do
    [
      Enum.map(product.options, &option_map/1) ++ brand_map(self_or_parent_product.brand)
    ]
  end

  defp generate_number_facet(product, _) do
    [
      %{
        id: "Price",
        value: Decimal.to_float(product.selling_price.amount)
      },
      %{
        id: "Discount",
        value: product_discount(product)
      }
    ]
  end

  defp gen_category_info(nil),
    do: %{
      direct_parent: "Other",
      all_parents: ["Other"],
      paths: "Other"
    }

  defp gen_category_info(taxon) do
    taxon = Repo.preload(taxon, :parent)
    paths = gen_taxon_path(taxon.parent) ++ [taxon.name]

    %{
      direct_parent: taxon.name,
      all_parents: paths,
      paths: Enum.join(paths, ":")
    }
  end

  defp gen_taxon_path(nil), do: []
  defp gen_taxon_path(%{parent: nil}), do: []

  defp gen_taxon_path(%{parent: parent, name: name}) do
    parent = Repo.preload(parent, :parent)
    gen_taxon_path(parent) ++ [name]
  end

  defp option_map(option) do
    %{
      id: option.option.display_name,
      value: option.value
    }
  end

  defp brand_map(nil), do: []

  defp brand_map(brand) do
    [
      %{
        id: "Brand",
        value: brand.name
      }
    ]
  end

  # If stand alone product, then use its images
  defp product_images(%{parent_variation: nil, images: images} = product) do
    Enum.map(images, &image_map(product, &1))
  end

  # If variant does not have images, then use parent images
  defp product_images(
         %{
           parent_variation: %{parent_product: %{images: parent_images, id: parent_id}},
           images: []
         } = product
       ) do
    product_images(%{product | parent_variation: nil, images: parent_images, id: parent_id})
  end

  # If variant has images, then use those images
  defp product_images(%{images: images} = product) do
    product_images(%{product | parent_variation: nil, images: images})
  end

  defp image_map(product, image) do
    %{
      product_url: ImageModel.image_url(image.name, product, :thumb)
    }
  end

  defp avg_rating(product) do
    %{
      average_rating: average_rating,
      review_count: review_count,
      rating_list: rating_list
    } = PRModel.review_aggregate(product)

    %{
      average_rating: average_rating |> Decimal.round(1) |> Decimal.to_float(),
      review_count: review_count,
      rating_list:
        Enum.map(rating_list, fn {k, %{value: v, position: p}} ->
          {k, %{value: v |> Decimal.round(1) |> Decimal.to_float(), position: p}}
        end)
        |> Enum.into(%{})
    }
  end

  defp suggest_keywords(%{name: name, meta_keywords: meta_keywords, tenant: tenant, taxon: taxon}) do
    keywords =
      gen_taxon_path(taxon) ++
        ("#{name} #{meta_keywords}"
         |> String.trim()
         |> String.downcase()
         |> String.split(~r(\s+|\s*\,\s*)))

    %{
      "input" => format_suggest_input(keywords),
      "contexts" => %{
        "tenant" => tenant
      }
    }
  end

  defp format_suggest_input([]), do: []

  defp format_suggest_input(keywords) do
    [h | t] = keywords
    [h <> " " <> Enum.join(t, " ") | format_suggest_input(t)]
  end

  defp format_money(money) do
    %{
      "currency" => money.currency,
      "amount" => Decimal.to_float(money.amount)
    }
  end

  defp product_discount(product) do
    try do
      product.max_retail_price.amount
      |> Decimal.sub(product.selling_price.amount)
      |> Decimal.div(product.max_retail_price.amount)
      |> Decimal.mult(100)
      |> Decimal.round(0)
      |> Decimal.to_integer()
      |> format_discount()
    rescue
      _ -> 0
    end
  end

  defp format_discount(discount) when discount > 100, do: 100
  defp format_discount(discount) when discount < 0, do: 0
  defp format_discount(discount), do: discount
end
