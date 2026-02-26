# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "i18n"
require "i18n/message_format"
require "minitest/autorun"

I18n.enforce_available_locales = false
