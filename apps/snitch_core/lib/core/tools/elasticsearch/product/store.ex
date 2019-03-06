defmodule Snitch.Tools.ElasticSearch.Product.Store do
  @moduledoc """
  Fetches data from product table to be used in product index
  """
  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias Snitch.Core.Tools.MultiTenancy.Repo
  alias Snitch.Data.Model.Product, as: PM
  alias Snitch.Tools.ElasticsearchCluster, as: EC

  @preload [
    :brand,
    :images,
    # Considering max nesting is 4 level
    # This will benifit unless forced preload
    # like => Repo.preload(taxon, :parent, force: true)
    taxon: [parent: [parent: [parent: :parent]]],
    parent_variation: [
      parent_product: [:brand, :images, reviews: [rating_option_vote: :rating_option]]
    ],
    reviews: [rating_option_vote: :rating_option],
    options: [:option]
  ]

  @index if Mix.env() == :test, do: "products_test", else: "products"

  @impl true
  @doc """
  Will be able to stream products from all the tenants,
  along with a tenant(virtual field) to track teanant in Elasticsearch
  """
  def stream(_schema) do
    ["public" | Triplex.all()]
    |> Stream.flat_map(fn tenant ->
      IO.puts("\n\t Streaming data for #{tenant} database \n")
      Repo.set_tenant(tenant)

      query =
        PM.sellable_products_query()
        |> select([p, v], merge(p, %{tenant: ^tenant}))
        |> preload([], ^@preload)

      Repo.stream(query)
    end)
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end

  def update_product_to_es(id, action \\ :create)

  def update_product_to_es(id, action) when is_binary(id),
    do: update_product_to_es(PM.get(id), action)

  def update_product_to_es(product, action) when is_map(product) do
    product = Repo.preload(%{product | tenant: Repo.get_prefix()}, [:variants | @preload])

    case product.variants do
      [] ->
        update_sellable_product_to_es(product, action)

      variants ->
        Enum.map(
          variants,
          fn variant ->
            %{variant | tenant: Repo.get_prefix()}
            |> Repo.preload(@preload)
            |> update_sellable_product_to_es(action)
          end
        )
    end
  end

  defp update_sellable_product_to_es(%{state: :active, deleted_at: 0} = product, :create),
    do:
      Elasticsearch.put_document!(
        EC,
        product,
        @index
      )

  # Incase product is not in active state, then delete the product
  defp update_sellable_product_to_es(product, :create),
    do: Elasticsearch.delete_document(EC, product, @index)

  defp update_sellable_product_to_es(product, :delete),
    do: Elasticsearch.delete_document(EC, product, @index)

  def search_products(query),
    do: Elasticsearch.post!(EC, "/#{@index}/_doc/_search", query)
end
