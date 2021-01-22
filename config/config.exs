import Config

import_config "#{Mix.env()}.exs"

config :plug, :statuses, %{420 => "Invalid Recaptcha"}
