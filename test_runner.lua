#!/usr/bin/env lua
--[[
Test runner for symbol.lua plugin

Usage: lua test_runner.lua [generate|test]
  generate - Run extraction and save expected output
  test     - Run extraction and compare against expected output
]]

-- Mock yazi APIs (plugin uses these but we don't need them for extraction testing)
ui = {}
ya = {}

-- Load the actual symbol plugin
local plugin = dofile("symbol.lua")

-- Get the extraction function (exposed for testing)
local extract_symbols = plugin._extract_symbols

if not extract_symbols then
  error("Plugin does not expose _extract_symbols for testing")
end

-- Test configuration
local tests = {
  { name = "Markdown", file = "fixtures/sample.md", ext = "md" },
  { name = "Python", file = "fixtures/sample.py", ext = "py" },
  { name = "JavaScript", file = "fixtures/sample.js", ext = "js" },
  { name = "TypeScript", file = "fixtures/sample.ts", ext = "ts" },
  { name = "Rust", file = "fixtures/sample.rs", ext = "rs" },
  { name = "Go", file = "fixtures/sample.go", ext = "go" },
}

-- Main execution
local mode = arg[1] or "test"

if mode == "generate" then
  print("Generating expected output files...")
  for _, test in ipairs(tests) do
    local symbols = extract_symbols(test.file, test.ext)
    local output_file = "expected/" .. test.name:lower() .. ".txt"
    local f = io.open(output_file, "w")
    for _, sym in ipairs(symbols) do
      f:write(string.format("[%s] %s\n", sym.type, sym.text))
    end
    f:close()
    print(string.format("  ✓ %s -> %s", test.name, output_file))
  end
  print("\nDone! Review the expected/ directory and commit if correct.")

elseif mode == "test" then
  print("Running tests...\n")
  local all_passed = true

  for _, test in ipairs(tests) do
    local symbols = extract_symbols(test.file, test.ext)
    local expected_file = "expected/" .. test.name:lower() .. ".txt"

    -- Read expected output
    local expected_lines = {}
    local f = io.open(expected_file, "r")
    if f then
      for line in f:lines() do
        table.insert(expected_lines, line)
      end
      f:close()
    else
      print(string.format("  ✗ %s - Missing expected file: %s", test.name, expected_file))
      all_passed = false
      goto continue
    end

    -- Generate actual output
    local actual_lines = {}
    for _, sym in ipairs(symbols) do
      table.insert(actual_lines, string.format("[%s] %s", sym.type, sym.text))
    end

    -- Compare
    if #actual_lines ~= #expected_lines then
      print(string.format("  ✗ %s - Line count mismatch (expected %d, got %d)",
        test.name, #expected_lines, #actual_lines))
      all_passed = false
    else
      local match = true
      for i = 1, #actual_lines do
        if actual_lines[i] ~= expected_lines[i] then
          print(string.format("  ✗ %s - Mismatch at line %d:", test.name, i))
          print(string.format("      Expected: %s", expected_lines[i]))
          print(string.format("      Got:      %s", actual_lines[i]))
          match = false
          all_passed = false
          break
        end
      end
      if match then
        print(string.format("  ✓ %s (%d symbols)", test.name, #symbols))
      end
    end

    ::continue::
  end

  print()
  if all_passed then
    print("All tests passed! ✓")
    os.exit(0)
  else
    print("Some tests failed! ✗")
    os.exit(1)
  end

else
  print("Usage: lua test_runner.lua [generate|test]")
  os.exit(1)
end
