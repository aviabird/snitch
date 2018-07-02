defmodule AdminAppWeb.Email do
  @moduledoc """
  Composing email to send forgot password token.
  """

  use Phoenix.Swoosh, view: AdminAppWeb.EmailView, layout: {AdminAppWeb.LayoutView, :email}
  import Swoosh.Email
  alias AdminAppWeb.Mailer

  def password_reset_mail(token, email, base_url) do
    new()
    |> to(email)
    |> from({"Snitch", "jyotigautam108@gmail.com"})
    |> subject("Update your password")
    |> render_body("password_reset_email.html", %{token: token, base_url: base_url})
    |> Mailer.deliver()
  end
end
