defmodule AdminAppWeb.OrderView do
  use AdminAppWeb, :view
  alias Phoenix.HTML.FormData
  alias Snitch.Data.Model.Order, as: OrderModel

  @bootstrap_contextual_class %{
    "cart" => "light",
    "address" => "light",
    "payment" => "light",
    "processing" => "warning",
    "shipping" => "warning",
    "shipped" => "info",
    "cancelled" => "secondary",
    "completed" => "success"
  }

  @summary_fields ~w(item_total adjustment_total promo_total total)a
  @summary_fields_capitalized Enum.map(@summary_fields, fn field ->
                                field
                                |> Atom.to_string()
                                |> String.replace("_", " ")
                                |> String.capitalize()
                              end)
  @summary_field_classes %{
    total: "table-secondary"
  }

  def colorize(%{state: state}) do
    "table-" <> Map.fetch!(@bootstrap_contextual_class, state)
  end

  def state_badge(state) do
    color_class = @bootstrap_contextual_class[state]
    content_tag(:span, state, class: "badge badge-pill badge-#{color_class}")
  end

  defp render_line_item(line_item, order) do
    content = [
      render_variant(line_item.variant),
      content_tag(:td, line_item.unit_price),
      render_quantity_with_stock(line_item),
      content_tag(:td, line_item.total),
      render_buttons(line_item.id, order)
    ]

    content_tag(:tr, List.flatten(content))
  end

  defp render_variant(variant) do
    [content_tag(:th, content_tag(:i, "", class: "far fa-image")), content_tag(:td, variant.sku)]
  end

  defp render_edit_button() do
    content_tag(
      :button,
      [
        "remove"
        # content_tag(:span, tag(:i, class: "far fa-edit"), class: "badge badge-light")
      ],
      class: "btn btn-primary",
      type: "submit"
    )
  end

  defp render_buttons(item, order) do
    if is_editable?(order.state) do
      content_tag(
        :td,
        form_tag("/orders/#{order.number}/cart?edit=#{item}", method: "post") do
          render_edit_button()
        end
      )
    end
  end

  defp render_quantity_with_stock(line_item) do
    content_tag(:td, "#{line_item.quantity} x on hand")
  end

  defp render_address(address) do
    content_tag(
      :p,
      [
        "#{address.first_name} #{address.last_name}",
        address.address_line_1,
        address.address_line_2,
        address.city,
        address.phone,
        address.zip_code
      ]
      |> Enum.reject(&(&1 == nil))
      |> Enum.intersperse([",", tag(:br)])
      |> List.flatten(),
      class: "text-center"
    )
  end

  defp summary(order) do
    content_tag(
      :tbody,
      @summary_fields
      |> Stream.zip(@summary_fields_capitalized)
      |> Enum.map(&make_summary_row(&1, order))
    )
  end

  defp make_summary_row({field, field_capitalized}, order) do
    content_tag(
      :tr,
      [
        content_tag(:th, field_capitalized, scope: "row"),
        content_tag(:td, Map.fetch!(order, field))
      ],
      class: Map.get(@summary_field_classes, field)
    )
  end

  defp is_editable?(_), do: true

  defp render_search_item(item, order) do
    content = [
      content_tag(:td, item.sku),
      content_tag(:td, item.selling_price),
      content_tag(:td, tag(:input, name: "quantity", id: "quantity")),
      content_tag(:td, content_tag(:button, ["Add"], type: "submit"))
    ]

    list =
      form_tag("/orders/#{order.number}/cart?add=#{item.id}", method: "put") do
        List.flatten(content)
      end

    content_tag(:tr, list)
  end
end
