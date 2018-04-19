defmodule Snitch.Data.Schema.PaymentMethodTest do
  use ExUnit.Case, async: true
  use Snitch.DataCase

  alias Snitch.Data.Schema.PaymentMethod

  test "PaymentMethods must have unique code" do
    params = %{name: "card-payments", code: "ccd"}
    card_method = PaymentMethod.create_changeset(%PaymentMethod{}, params)
    assert %Ecto.Changeset{valid?: true} = card_method
    assert {:ok, _} = Repo.insert(card_method)
    assert {:error, %Ecto.Changeset{errors: errors}} = Repo.insert(card_method)
    assert errors == [code: {"has already been taken", []}]
  end

  test "PaymentMethod `:update` ignores changes to `:code`" do
    create_params = %{name: "card-payments", code: "ccd"}
    card_method = PaymentMethod.create_changeset(%PaymentMethod{}, create_params)
    assert {:ok, _} = Repo.insert(card_method)

    update_params = %{name: "by card", active?: false}

    %Ecto.Changeset{changes: changes} =
      PaymentMethod.update_changeset(%PaymentMethod{}, update_params)

    assert changes == update_params
  end
end
