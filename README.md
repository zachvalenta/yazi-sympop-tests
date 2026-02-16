# Symbol Plugin Test Suite

Test suite for the yazi symbol preview plugin. These tests ensure the plugin correctly extracts symbols from various programming languages.

## Structure

```
/tmp/symbol-plugin-tests/
├── symbol.lua          # Current working plugin (copy from yazi)
├── test_runner.lua     # Test harness
├── fixtures/           # Sample code files for testing
│   ├── sample.md       # Markdown with multiple header levels, code blocks
│   ├── sample.py       # Python with classes, methods, functions
│   ├── sample.js       # JavaScript with classes, functions, exports
│   ├── sample.ts       # TypeScript with types
│   ├── sample.rs       # Rust with structs, enums, impl blocks
│   └── sample.go       # Go with types, functions, methods
└── expected/           # Expected output for each test
    ├── markdown.txt
    ├── python.txt
    ├── javascript.txt
    ├── typescript.txt
    ├── rust.txt
    └── go.txt
```

## Requirements

- LuaJIT (or Lua 5.1+)

## Running Tests

**Test against expected output:**
```bash
cd /tmp/symbol-plugin-tests
luajit test_runner.lua test
```

**Regenerate expected output:**
```bash
luajit test_runner.lua generate
```

## Languages Tested

- **Markdown** (.md) - Headers (H1-H4), ignores code blocks
- **Python** (.py) - Classes, methods, top-level functions
- **JavaScript** (.js) - Classes, methods, functions, exports
- **TypeScript** (.ts) - Same as JS
- **Rust** (.rs) - Structs, enums, impl blocks, pub/private functions
- **Go** (.go) - Types, functions, methods with receivers

## Test Coverage

Each fixture exercises:
- Basic symbol extraction
- Nesting (methods under classes/types)
- Edge cases (code blocks, indentation, context tracking)

## Next Steps

After refactoring the plugin:
1. Copy new version to `symbol.lua`
2. Run `luajit test_runner.lua test`
3. All tests should still pass (regression protection)
