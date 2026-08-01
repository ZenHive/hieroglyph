# Reach architecture/smell policy for `mix reach.check --arch --smells`.
#
# Flat single-namespace library (`ABI.*`): the facade (abi.ex) and its encode/
# decode/parse/math submodules are mutually consulted with no enforceable
# facade-vs-internal or generator-vs-output split — the Solidity ABI grammar
# lives in generated Erlang (src/*.yrl, src/*.xrl -> yecc/leex), outside
# reach's Elixir source scan. The one Mix task
# (lib/mix/tasks/hieroglyph.manifest.ex) depends on the runtime lib one-way,
# as any packaging task does. No `layers`/`deps`.
[
  smells: [strict: true]
]
