# frozen_string_literal: true

require_relative "lib/codepulse"

Gem::Specification.new do |spec|
  spec.name = "codepulse"
  spec.version = Codepulse::VERSION
  spec.authors = ["Patrick Navarro"]
  spec.email = ["patrick@workbright.com"]

  spec.summary = "GitHub PR pickup time metrics"
  spec.description = "Terminal tool to analyze GitHub pull request pickup times, merge times, and sizes using the gh CLI."
  spec.homepage = "https://github.com/workbright/codepulse"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["allowed_push_host"] = ""

  spec.files = Dir.glob([
                          "lib/**/*.rb",
                          "bin/*",
                          "README.md"
                        ])

  spec.bindir = "bin"
  spec.executables = ["codepulse"]

  spec.require_paths = ["lib"]
end
