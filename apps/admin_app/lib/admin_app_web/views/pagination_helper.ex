defmodule AdminAppWeb.PaginationHelpers do
  import Phoenix.HTML
  import Phoenix.HTML.Form
  import Phoenix.HTML.Link
  import Phoenix.HTML.Tag

  def pagination_text(list) do
    content_tag :div, class: "text-primary" do
      "Displaying #{list.first}-#{list.last} of #{list.count}"
    end
  end

  defp fetch_params(%Plug.Conn.Unfetched{} = params) do
    %{}
  end

  defp fetch_params(params) do
    params
  end

  def pagination_links(conn, list, route) do

    params = fetch_params(conn.params)
    content_tag :div, class: "pagination", data: [category: params["category"]] do
      children = []

      page_links =
        get_previous(children, conn, params, list, route) ++ get_next(children, conn, params, list, route)

      {:safe, page_links}
    end
  end

  defp get_previous(children, conn, params, list, route) do
    case list.has_prev do
      true ->
        {:safe, children} =
          children ++
            link("Previous",
              to: route.(conn, :index, Map.put(params, "page", list.prev_page)),
              class: "pagination-btn btn btn-primary btn-lg",
              data: [page: list.prev_page] 
            )

        children

      false ->
        children
    end
  end

  defp get_next(children, conn, params, list, route) do
    case list.has_next do
      true ->
        {:safe, children} =
          children ++
            link("Next",
              to: route.(conn, :index, Map.put(params, "page", list.next_page)),
              class: "pagination-btn btn btn-primary btn-lg",
              data: [page: list.next_page] 
            )

        children

      false ->
        children
    end
  end
end