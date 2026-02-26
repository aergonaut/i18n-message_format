# I18n::MessageFormat

ICU Message Format support for the Ruby [i18n](https://github.com/ruby-i18n/i18n) gem. Pure Ruby parser, no native dependencies.

## Installation

```bash
bundle add i18n-message_format
```

## Usage

### Standalone

```ruby
require "i18n/message_format"

I18n::MessageFormat.format(
  "{name} has {count, plural, one {# item} other {# items}}",
  name: "Alice", count: 3
)
# => "Alice has 3 items"
```

### With I18n Backend

Store your Message Format strings in separate YAML files:

```yaml
# config/locales/mf/en.yml
en:
  greeting: "Hello {name}!"
  items: "{count, plural, one {# item} other {# items}}"
```

Configure the backend:

```ruby
I18n.backend = I18n::Backend::Chain.new(
  I18n::MessageFormat::Backend.new("config/locales/mf/*.yml"),
  I18n::Backend::Simple.new
)

I18n.t("greeting", name: "Alice")
# => "Hello Alice!"
```

### Supported Syntax

- Simple arguments: `{name}`
- Number format: `{count, number}`
- Date format: `{d, date, short}`
- Time format: `{t, time, short}`
- Plural: `{count, plural, one {# item} other {# items}}`
- Select: `{gender, select, male {He} female {She} other {They}}`
- Selectordinal: `{pos, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}`
- Nested messages
- Escaped braces: `'{ '} ''`

### Ordinal Rules

Install built-in ordinal rules for selectordinal support:

```ruby
I18n::MessageFormat::OrdinalRules.install(:en)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Run tests with `bundle exec rake test`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/aergonaut/i18n-message_format. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/aergonaut/i18n-message_format/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
