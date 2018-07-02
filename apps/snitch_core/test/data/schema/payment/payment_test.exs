defmodule Snitch.Data.Schema.PaymentTest do
  use ExUnit.Case, async: true
  use Snitch.DataCase

  import Snitch.Factory

  alias Snitch.Data.Schema.Payment
  alias Snitch.Data.Model.Payment, as: PaymentModel

  setup do
    [order: insert(:order)]
  end

  setup :payment_methods

  test "Payments invalidate bad type", context do
    %{check_method: method, order: order} = context

    check_payment =
      :payment_chk
      |> build(payment_method_id: method.id, order_id: order.id)
      |> Payment.create_changeset(%{payment_type: "abc"})

    assert %Ecto.Changeset{errors: errors} = check_payment
    assert errors == [payment_type: {"is invalid", [validation: :inclusion]}]
  end

  test "Payments cannot have negative amount", context do
    %{check_method: method, order: order} = context

    check_payment =
      :payment_chk
      |> build(payment_method_id: method.id, order_id: order.id)
      |> Payment.create_changeset(%{amount: Money.new("-0.0001", :USD)})

    assert %Ecto.Changeset{errors: errors} = check_payment
    assert errors == [amount: {"must be equal or greater than 0", [validation: :number]}]
  end

  test "Payments create chk", context do
    %{check_method: method, order: order} = context

    check_payment =
      :payment_chk
      |> build(payment_method_id: method.id, order_id: order.id)
      |> Payment.create_changeset(%{amount: Money.new("10.00", :USD)})

    assert {:ok, payment} = PaymentModel.create(check_payment)
    assert payment.amount == Money.new("10.00", :USD)
  end

  test "Payments create card", context do
    %{check_method: method, order: order} = context

    check_payment =
      :payment_ccd
      |> build(payment_method_id: method.id, order_id: order.id)
      |> Payment.create_changeset(%{amount: Money.new("10.00", :USD)})

    assert {:ok, payment} = PaymentModel.create(check_payment)
    assert payment.amount == Money.new("10.00", :USD)
  end
end
