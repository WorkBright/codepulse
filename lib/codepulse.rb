# frozen_string_literal: true

require_relative "codepulse/errors"
require_relative "codepulse/time_helpers"
require_relative "codepulse/base_client"
require_relative "codepulse/gh_cli_client"
require_relative "codepulse/metrics_calculator"
require_relative "codepulse/formatter"
require_relative "codepulse/cli"

module Codepulse
  VERSION = "0.1.1"
end
