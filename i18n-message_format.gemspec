# frozen_string_literal: true

require_relative "lib/i18n/message_format/version"

Gem::Specification.new do |spec|
  spec.name = "i18n-message_format"
  spec.version = I18n::MessageFormat::VERSION
  spec.authors = ["Chris Fung"]
  spec.email = ["aergonaut@gmail.com"]

  spec.summary = "ICU Message Format support for Ruby i18n"
  spec.description = "A pure Ruby implementation of ICU Message Format that integrates with the ruby-i18n gem via a chainable backend."
  spec.homepage = "https://github.com/aergonaut/i18n-message_format"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/aergonaut/i18n-message_format"
  spec.metadata["changelog_uri"] = "https://github.com/aergonaut/i18n-message_format/blob/main/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ Gemfile .gitignore])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "i18n", ">= 1.0"
end
