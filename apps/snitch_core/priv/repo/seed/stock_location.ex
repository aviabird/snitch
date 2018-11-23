defmodule Snitch.Seed.StockLocation do
  alias Snitch.Core.Tools.MultiTenancy.Repo
  alias Snitch.Data.Schema.{State, StockLocation}

  def seed!() do
    Repo.delete_all(StockLocation)
    state = get_random_state

    create_stock_location!(
      "default",
      "default",
      true,
      "Oxford Hallmark",
      "Street 1",
      "abc",
      "232233",
      "8877996675",
      true,
      true,
      state,
      state.country
    )
  end

  defp get_random_state do
    State
    |> Repo.all()
    |> Repo.preload([:country])
    |> Enum.random()
  end

  def create_stock_location!(
        name,
        admin_name,
        default,
        address_line_1,
        address_line_2,
        city,
        zip_code,
        phone,
        propagate_all_variants,
        active,
        state,
        country
      ) do
    params = %{
      name: name,
      admin_name: admin_name,
      default: default,
      address_line_1: address_line_1,
      address_line_2: address_line_2,
      city: city,
      zip_code: zip_code,
      phone: phone,
      propagate_all_variants: propagate_all_variants,
      active: active,
      state_id: state.id,
      country_id: country.id
    }

    %StockLocation{} |> StockLocation.create_changeset(params) |> Repo.insert!()
  end
end
