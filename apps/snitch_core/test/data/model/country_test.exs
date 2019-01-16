defmodule Snitch.Data.Model.CountryTest do
  use ExUnit.Case, async: true
  use Snitch.DataCase
  alias Snitch.Data.Model.Country
  import Snitch.Factory

  setup :countries

  describe "Country formatting" do
    test "for a single country ", %{countries: countries} do
      country = countries |> List.first()
      country_list = Country.formatted_list()
      assert country_list == [{country.name, country.id}]
    end
  end

  describe "get/1" do
    test "succeeds", %{countries: countries} do
      country = countries |> List.first()
      country_list = Country.get(%{numcode: country.numcode})
      assert country_list == country
    end

    test "fails" do
      country_list = Country.get(%{numcode: "842"})
      assert country_list == nil
    end
  end

  describe "get_all/0" do
    test "succeds", %{countries: countries} do
      country_list = Country.get_all()
      assert length(country_list) == length(countries)
    end
  end
end
