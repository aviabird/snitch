defmodule AdminAppWeb.ProductController do
  use AdminAppWeb, :controller

  alias Snitch.Core.Tools.MultiTenancy.Repo
  alias Snitch.Data.Model.Product, as: ProductModel
  alias Snitch.Data.Model
  alias Snitch.Data.Schema.Product, as: ProductSchema
  alias Snitch.Domain.Taxonomy
  alias Snitch.Tools.Helper.Rummage, as: RummageHelper
  alias Snitch.Domain.Inventory
  alias Snitch.Tools.ElasticSearch.Product.Store, as: ESProductStore

  alias Snitch.Data.Schema.{
    ProductBrand,
    StockLocation,
    VariationTheme,
    ProductProperty,
    Property
  }

  alias Snitch.Tools.Helper.Query
  alias Snitch.Data.Model.Image, as: ImageModel
  alias AdminAppWeb.ProductView

  import Phoenix.View, only: [render_to_string: 3]
  import Phoenix.HTML.Format
  import Phoenix.HTML

  plug(:load_resources when action in [:new, :edit, :create])

  @rummage_default %{
    "rummage" => %{
      "search" => %{
        "state" => %{"search_expr" => "where", "search_term" => "active", "search_type" => "eq"}
      },
      "sort" => %{"field" => "name", "order" => "asc"}
    }
  }

  def index(conn, params) do
    if params["rummage"] do
      products = ProductModel.get_rummage_product_list(params["rummage"])

      render(conn, "index.html", products: products)
    else
      redirect_with_updated_conn(conn, @rummage_default)
    end
  end

  def new(conn, _params) do
    changeset = ProductSchema.create_changeset(%ProductSchema{}, %{})

    render(conn, "new.html",
      changeset: changeset,
      rummage_params: RummageHelper.get_rummage_params(conn)
    )
  end

  def create(conn, %{"product" => params}) do
    with {:ok, product} <- ProductModel.create(params) do
      save_publish_redirect_handler(conn, product, params)
    else
      {:error, changeset} ->
        conn = %{conn | request_path: product_path(conn, :new)}
        conn = %{conn | params: conn.params |> Map.put("taxon_id", Map.get(params, "taxon_id"))}

        render(conn, "new.html",
          changeset: %{changeset | action: :new},
          rummage_params: RummageHelper.get_rummage_params(conn)
        )
    end
  end

  def edit(conn, %{"id" => id} = params) do
    preloads = [variants: [options: :option], images: [], taxon: [:variation_themes]]

    with {:ok, %ProductSchema{} = product} <- ProductModel.get(id) do
      product = product |> Repo.preload(preloads)
      changeset = ProductSchema.update_changeset(product, params)

      rummage_params = RummageHelper.get_rummage_params(conn)

      render(conn, "edit.html",
        changeset: changeset,
        parent_product: product,
        rummage_params: rummage_params
      )
    else
      {:error, :product_not_found} ->
        conn
        |> put_flash(:error, "Product not found")
        |> redirect(to: "/")
    end
  end

  def update(conn, %{"product" => params}) do
    with {:ok, %ProductSchema{} = product} <- ProductModel.get(params["id"]),
         {:ok, product} <- ProductModel.update(product, params) do
      updated_params = conn.params |> Map.take(["rummage"]) |> Map.merge(params)
      save_publish_redirect_handler(conn, product, updated_params)
    end
  end

  def update_inventory_tracking(conn, %{"product" => product_params} = params) do
    with {:ok, %ProductSchema{} = product} <- ProductModel.get(params["product_id"]) do
      tracking_level = product_params["inventory_tracking"]
      Inventory.set_inventory_tracking(product, tracking_level, params)

      redirect(conn, to: product_path(conn, :edit, product.id))
    end
  end

  def save_publish_redirect_handler(conn, _product, %{"publish_redirection" => "true"} = params) do
    redirect_with_updated_conn(conn, params)
  end

  def save_publish_redirect_handler(conn, product, %{"publish_redirection" => "false"} = _params) do
    redirect(conn, to: product_path(conn, :edit, product.id))
  end

  def save_publish_redirect_handler(conn, _product, params) do
    redirect_with_updated_conn(conn, params)
  end

  def toggle_variant_state(conn, %{"state" => state, "id" => product_id}) do
    {:ok, product} = ProductModel.get(%{id: product_id})

    case ProductModel.update(product, %{state: state}) do
      {:ok, _} ->
        conn
        |> put_status(200)
        |> json(%{state: state})

      {:error, reason} ->
        conn
        |> put_flash(:error, reason)
        |> json(%{state: "error occured"})
    end
  end

  defp get_html_string(product, image) do
    render_to_string(
      ProductView,
      "upload_image.html",
      parent_product: product,
      image: image
    )
  end

  defp preload_product_images(id) do
    {:ok, product} = ProductSchema |> Query.get(id, Repo)
    product |> Repo.preload(:images)
  end

  def update_default_image(conn, %{"product_id" => id, "default_image" => default_image}) do
    product = preload_product_images(id)

    ProductModel.update_default_image(product, default_image)
    ESProductStore.update_product_to_es(product)

    conn
    |> put_status(200)
    |> json(%{msg: "Update successful"})
  end

  def add_images(conn, %{"product_images" => product_images, "product_id" => id}) do
    product = preload_product_images(id)

    images =
      product
      |> parse_images(product_images["images"] ++ product.images)

    params = %{"images" => images}

    case ProductModel.add_images(product, params) do
      {:ok, updated_product} ->
        ESProductStore.update_product_to_es(updated_product)
        associated_images = product.images
        product = product |> Repo.preload(:images, force: true)

        product_images =
          case Enum.empty?(associated_images) do
            true ->
              ImageModel.update(%{is_default: true}, product.images |> List.first())
              product = product |> Repo.preload(:images, force: true)
              product.images

            false ->
              product.images -- associated_images
          end

        image_div = Enum.map(product_images, fn image -> get_html_string(product, image) end)
        images = Enum.join(image_div, " ")
        opts = [wrapper_tag: :div, attributes: [class: "alert alert-success"]]
        html = text_to_html("Image uploaded succesully", opts) |> safe_to_string

        conn
        |> put_status(200)
        |> json(%{html: html, images: images})

      {:error, _} ->
        opts = [wrapper_tag: :div, attributes: [class: "alert alert-danger"]]

        html =
          text_to_html("Problem uploading image, try a valid image format", opts)
          |> safe_to_string

        conn
        |> put_status(422)
        |> json(%{html: html})
    end
  end

  def delete_image(conn, %{"image_id" => image_id, "product_id" => product_id}) do
    image_id = String.to_integer(image_id)
    {:ok, product} = String.to_integer(product_id) |> ProductModel.get()

    case ProductModel.delete_image(product.id, image_id) do
      {:ok, _} ->
        product
        |> ESProductStore.update_product_to_es()

        conn
        |> put_status(200)
        |> json(%{data: "success"})

      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{data: reason})
    end
  end

  defp parse_images(product, image_list) do
    Enum.reduce(image_list, [], fn
      %Plug.Upload{} = image, acc ->
        image = ImageModel.handle_image_value(image)

        image = image |> Map.put(:url, ImageModel.image_url(image.filename, product))

        [%{"image" => image} | acc]

      image, acc ->
        %{id: id, name: name} = Map.from_struct(image)
        [%{"id" => id, "name" => name} | acc]
    end)
  end

  def delete(conn, %{"id" => id} = params) do
    with {:ok, _product} <- ProductModel.delete(id) do
      conn
      |> put_flash(:info, "Product deleted successfully")
      |> redirect_with_updated_conn(params)
    end
  end

  def new_variant(conn, params) do
    with {:ok, %ProductSchema{} = parent_product} <- ProductModel.get(params["product_id"]),
         variant_params <- generate_variant_params(parent_product, params["options"]),
         %Ecto.Changeset{valid?: true} = changeset <-
           ProductSchema.variant_create_changeset(parent_product, %{
             "variations" => variant_params,
             "theme_id" => params["theme_id"]
           }),
         {:ok, _product} = updated_product <- Repo.update(changeset) do
      ESProductStore.update_product_to_es(parent_product)
      redirect(conn, to: product_path(conn, :edit, params["product_id"]))
    else
      _ ->
        conn
        |> put_flash(:error, "Failed to create variant")
        |> redirect(to: product_path(conn, :edit, params["product_id"]))
    end
  end

  def delete_variant(conn, %{"id" => id, "parent_id" => parent_id} = params) do
    with {:ok, _product} = deleted_variant <- ProductModel.delete(id) do
      conn
      |> put_flash(:info, "Variant deleted successfully")
      |> redirect(to: product_path(conn, :edit, parent_id))
    else
      _ ->
        conn
        |> put_flash(:error, "Failed to delete variant")
        |> redirect(to: product_path(conn, :edit, parent_id))
    end
  end

  def select_category(conn, _params) do
    with {:ok, taxonomy} <- Taxonomy.get_default_taxonomy(),
         taxonomy <- Repo.preload(taxonomy, :root),
         {:ok, taxons} <- Taxonomy.get_child_taxons(taxonomy.root.id) do
      render(conn, "product_category.html", taxons: taxons)
    else
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Taxonomy not found")
        |> redirect(to: "/")
    end
  end

  def generate_variant_params(parent_product, options) do
    options =
      options
      |> Map.to_list()
      |> Enum.map(fn {_index, map} ->
        map["value"]
        |> String.trim()
        |> String.split(",")
        |> Enum.map(fn option_value ->
          %{option_id: map["option_type_id"], value: option_value}
        end)
      end)

    generate_option_combinations(options, [])
    |> Enum.map(fn options ->
      %{
        "child_product" => %{
          name: product_name_from_options(parent_product, options),
          options: options,
          selling_price: parent_product.selling_price,
          max_retail_price: parent_product.max_retail_price,
          taxon_id: parent_product.taxon_id,
          shipping_category_id: parent_product.shipping_category_id
        }
      }
    end)
  end

  defp product_name_from_options(product, options) do
    options
    |> Enum.reduce(product.name, fn x, acc -> "#{acc} #{x.value}" end)
  end

  def generate_option_combinations([head | tail], []) do
    acc =
      head
      |> Enum.map(&[&1])

    generate_option_combinations(tail, acc)
  end

  def generate_option_combinations([], acc) do
    acc
  end

  def generate_option_combinations([head | tail], acc) do
    result =
      acc
      |> Enum.flat_map(fn v ->
        head
        |> Enum.map(fn x -> v ++ [x] end)
      end)

    generate_option_combinations(tail, result)
  end

  def export_product(conn, %{"format" => format}) do
    current_user = Guardian.Plug.current_resource(conn)

    params =
      Map.put(
        %{"type" => "product", "format" => format, "user" => current_user},
        "tenant",
        Repo.get_prefix()
      )

    Honeydew.async({:export_data, [params]}, :export_data_queue)

    conn
    |> put_flash(:info, "Your request is accepted. Data will be emailed shortly")
    |> redirect(to: page_path(conn, :index))
  end

  def load_resources(conn, _opts) do
    load(conn, conn.params)
  end

  defp load(conn, _params) do
    themes = Repo.all(VariationTheme)

    brands = Repo.all(ProductBrand)

    stock_locations = Repo.all(StockLocation)

    conn
    |> assign(:token, get_csrf_token())
    |> assign(:themes, themes)
    |> assign(:stock_locations, stock_locations)
    |> assign(:brands, brands)

    # |> assign(:prototype, prototype)
  end

  defp redirect_with_updated_conn(conn, params) do
    rummage_params = params |> Map.take(["rummage"])

    updated_conn =
      conn
      |> Map.put(:query_params, rummage_params)
      |> Map.put(:query_string, Plug.Conn.Query.encode(rummage_params))

    redirect(updated_conn, to: product_path(updated_conn, :index, rummage_params))
  end

  def index_property(conn, _params) do
    render(conn, "property_index.html")
  end

  def new_property(conn, params) do
    changeset =
      ProductProperty.create_changeset(%ProductProperty{}, %{product_id: params["product_id"]})

    render(conn, "property_new.html",
      conn: conn,
      changeset: changeset,
      product_id: params["product_id"]
    )
  end

  def create_property(conn, params) do
    with {:ok, %ProductSchema{} = _product} <- ProductModel.get(params["product_id"]),
         {:ok, %Property{} = _property} <-
           Model.Property.get(params["product_property"]["property_id"]),
         {:ok, _product_property} <- Model.ProductProperty.create(params["product_property"]) do
      redirect(conn, to: product_path(conn, :edit, params["product_id"]))
    else
      {:error, changeset} ->
        render(conn, "property_new.html", changeset: changeset)
    end
  end

  def edit_property(conn, params) do
    changeset = ProductProperty.update_changeset(%ProductProperty{}, params)
    render(conn, "property_edit.html", changeset: changeset, conn: conn)
  end

  def update_property(conn, params) do
    with {:ok, %ProductProperty{} = product_property} <-
           Model.ProductProperty.get_by(%{
             product_id: params["product_property"]["product_id"],
             property_id: params["product_property"]["property_id"]
           }),
         {:ok, _} = Model.ProductProperty.update(product_property, params["product_property"]) do
      redirect(conn, to: product_path(conn, :edit, params["product_property"]["product_id"]))
    else
      {:error, changeset} ->
        render(conn, "property_edit.html", changeset: changeset, conn: conn)
    end
  end

  def delete_property(conn, params) do
    with {:ok, %ProductProperty{} = product_property} <-
           Model.ProductProperty.get_by(%{
             product_id: params["product_id"],
             property_id: params["property_id"]
           }),
         {:ok, _} <- Model.ProductProperty.delete(product_property) do
      conn
      |> put_flash(:info, "Product property deleted successfully")

      redirect(conn, to: product_path(conn, :edit, params["product_id"]))
    end
  end
end
