defmodule Raga.Repo do
  use Ecto.Repo,
    otp_app: :raga,
    adapter: Ecto.Adapters.Postgres
end
