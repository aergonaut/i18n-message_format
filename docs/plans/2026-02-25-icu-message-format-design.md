# ICU Message Format for Ruby i18n — Design

## Overview

`i18n-message_format` is a Ruby gem that adds ICU Message Format support to the
`i18n` gem. It provides a pure Ruby parser, a formatter integrated with existing
i18n infrastructure, and a chainable backend for seamless use alongside standard
translation files.

## Architecture

```
YAML files --> Backend (load + lookup) --> Parser (string -> AST) --> Formatter (AST + args -> string)
                                                   |
                                             LRU Cache (pattern -> AST)
```

Three layers:

1. **Parser** — recursive descent parser, string to AST
2. **Formatter** — AST walker, resolves arguments to produce output
3. **Backend** — `I18n::Backend::Base` implementation for use with `I18n::Backend::Chain`

## Parser

Pure Ruby recursive descent parser supporting the full ICU Message Format spec:

- Literal text
- Simple arguments: `{name}`
- Formatted arguments: `{count, number}`, `{date, date, short}`
- Plural: `{count, plural, one {# item} other {# items}}`
- Select: `{gender, select, male {He} female {She} other {They}}`
- Selectordinal: `{position, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}`
- Nested messages (full recursive nesting)
- Escaped braces: `'{` `'}` `''`

### AST Node Types

- `TextNode` — literal text
- `ArgumentNode` — simple argument reference
- `PluralNode` — plural selection
- `SelectNode` — value-based selection
- `SelectOrdinalNode` — ordinal plural selection
- `NumberFormatNode` — number formatting
- `DateFormatNode` — date formatting
- `TimeFormatNode` — time formatting

## Formatter

Walks the AST and resolves each node:

- **TextNode** — returns literal string
- **ArgumentNode** — looks up named argument, calls `to_s`
- **PluralNode** — uses i18n gem's plural rules (`i18n.plural.rule`) to pick the
  correct branch. Handles exact matches (`=0`, `=1`). Replaces `#` with the
  numeric value.
- **SelectNode** — matches argument value against branches, falls back to `other`
- **SelectOrdinalNode** — uses ordinal plural rules (`i18n.ordinal.rule`
  convention, see below)
- **NumberFormatNode** — formats via `I18n.l` / i18n number formatting
- **DateFormatNode / TimeFormatNode** — formats via `I18n.l(value, format: style)`

## Plural Rules

### Cardinal (plural)

Delegates to the i18n gem's existing pluralization infrastructure:

- Looks up `i18n.plural.rule` in locale data (returns a lambda: count -> category)
- Compatible with `rails-i18n` and other gems that ship pluralization rules
- Falls back to English rules (1 = `:one`, else `:other`) when no rule is found

### Ordinal (selectordinal)

The i18n gem has no built-in ordinal convention. This gem defines one:

- Convention: `i18n.ordinal.rule` in locale data (same lambda pattern)
- Ships built-in ordinal rules for common locales (English, etc.)
- Users or other gems can register additional ordinal rules

## Backend

`I18n::MessageFormat::Backend` implements `I18n::Backend::Base`.

```ruby
I18n.backend = I18n::Backend::Chain.new(
  I18n::MessageFormat::Backend.new("config/locales/mf/*.yml"),
  I18n::Backend::Simple.new
)
```

- Loads translations from separate, configurable file paths (glob patterns)
- All strings in those files are treated as Message Format patterns
- On `translate`: parses the pattern (or fetches from cache), formats with arguments
- Returns `nil` for missing keys so Chain falls through to the next backend
- Uses standard i18n YAML structure (`en.some.key`)

## LRU Cache

- Keyed by raw pattern string
- Default capacity: 1000 entries (configurable)
- Thread-safe via `Mutex`
- Stores parsed AST nodes

## Public API

```ruby
# Standalone usage
I18n::MessageFormat.format(
  "{name} has {count, plural, one {# item} other {# items}}",
  name: "Alice", count: 3
)
# => "Alice has 3 items"

# Backend integration
I18n.backend = I18n::Backend::Chain.new(
  I18n::MessageFormat::Backend.new("config/locales/mf/*.yml"),
  I18n::Backend::Simple.new
)
I18n.t("items.count", name: "Alice", count: 3)
```

## Error Handling

- `I18n::MessageFormat::ParseError` — malformed patterns (includes line/column)
- `I18n::MessageFormat::MissingArgumentError` — required argument not provided
- Both inherit from `I18n::MessageFormat::Error`

## Dependencies

- **Runtime**: `i18n` gem only
- **Development**: `minitest`, `rake`
- **Ruby**: >= 3.2.0

## Testing

- Minitest
- Parser tests covering all node types, nesting, edge cases, and error reporting
- Formatter tests for each format type with multiple locales
- Backend integration tests with Chain
- Cache behavior tests
