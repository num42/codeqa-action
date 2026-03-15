import Config

config :codeqa, :git_adapter, CodeQA.Git.SystemAdapter

import_config "#{config_env()}.exs"
