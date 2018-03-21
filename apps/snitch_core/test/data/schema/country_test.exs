defmodule Snitch.Data.Schema.CountryTest do
  use ExUnit.Case, async: true
  use Snitch.DataCase

  alias Snitch.Repo
  alias Snitch.Data.Schema.Country

  @valid_attrs %{
    iso_name: "INDIA",
    iso: "IN",
    iso3: "IND",
    name: "India",
    numcode: "356"
  }

  describe "Countries" do
    test "with valid attributes" do
      %{valid?: validity} = Country.changeset(%Country{}, @valid_attrs)
      assert validity
    end

    test "with invalid attributes" do
      params = Map.delete(@valid_attrs, :numcode)
      %{valid?: validity} = Country.changeset(%Country{}, params)
      refute validity
    end

    test "with invalid iso" do
      params = Map.update!(@valid_attrs, :iso, fn _ -> "IND" end)
      c_changeset = %{valid?: validity} = Country.changeset(%Country{}, params)
      refute validity
      assert %{iso: ["should be 2 character(s)"]} = errors_on(c_changeset)
    end

    test "with invalid iso3" do
      params = Map.update!(@valid_attrs, :iso3, fn _ -> "INDI" end)
      c_changeset = %{valid?: validity} = Country.changeset(%Country{}, params)
      refute validity
      assert %{iso3: ["should be 3 character(s)"]} = errors_on(c_changeset)
    end

    test "with dupilicate iso" do
      Repo.insert!(%Country{
        name: "India",
        iso_name: "INDIA",
        iso: "IN",
        iso3: "IND",
        numcode: "356"
      })

      changeset = Country.changeset(%Country{}, @valid_attrs)

      {:error, changeset} = Repo.insert(changeset)
      assert [iso: {"has already been taken", []}] = changeset.errors
    end

    test "with some blank value" do
      param = Map.delete(@valid_attrs, :name)
      c_changeset = %{valid?: validity} = Country.changeset(%Country{}, param)
      refute validity
      assert %{name: ["can't be blank"]} = errors_on(c_changeset)
    end
  end
end