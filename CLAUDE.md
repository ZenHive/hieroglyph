@~/.claude/includes/across-instances.md
@~/.claude/includes/critical-rules.md
@~/.claude/includes/task-prioritization.md
@~/.claude/includes/task-writing.md
@~/.claude/includes/workflow-philosophy.md
@~/.claude/includes/web-command.md
@~/.claude/includes/elixir-setup.md
@~/.claude/includes/ex-unit-json.md
@~/.claude/includes/dialyzer-json.md
@~/.claude/includes/code-style.md
@~/.claude/includes/development-commands.md
@~/.claude/includes/development-philosophy.md

# ABI

Pure Elixir library for encoding/decoding the Solidity ABI. No runtime processes — `ABI.encode/2`, `ABI.decode/2`, and the `TypeEncoder`/`TypeDecoder`/`FunctionSelector`/`Event` modules under `lib/abi/` are all stateless functions.

## Layout

- `lib/abi.ex` — public surface (`encode`, `decode`, `parse_specification`)
- `lib/abi/type_encoder.ex` / `type_decoder.ex` — head/tail packing for static and dynamic Solidity types
- `lib/abi/function_selector.ex` — parses `"foo(uint256,address)"` strings; uses generated yecc/leex parsers in `src/`
- `lib/abi/event.ex` — log decoding (indexed vs non-indexed args, topic hashing)
- `src/*.xrl` / `src/*.yrl` — leex/yecc grammar; compiled by the `:yecc, :leex` Mix compilers (see `mix.exs:18`). Edit the `.xrl`/`.yrl`, never the generated `.erl`.

## Gotchas

- `parse_specification/2` accepts `:string_keys` to keep ABI JSON keys as strings rather than atoms — preserve this when touching selector parsing.
- `TypeEncoder` recently grew integer- and string-key support (commits `a43e9d5`, `46accc8`); when adding new type paths, mirror both keyed-map and tuple input shapes.
- This library is consumed downstream by transaction builders. Breaking the public encode/decode shape is a major-version event — bump `version` in `mix.exs` accordingly.
