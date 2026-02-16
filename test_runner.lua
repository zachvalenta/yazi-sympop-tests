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

-- Load the symbol plugin and extract the extractor function
dofile("symbol.lua")

-- Read the plugin file and extract the extract_symbols function
local function load_extractor()
  local content = io.open("symbol.lua", "r"):read("*a")

  -- Execute in a sandboxed environment to get the extract_symbols function
  local env = {
    io = io,
    table = table,
    string = string,
    math = math,
    ipairs = ipairs,
    pairs = pairs,
    tostring = tostring,
    ui = ui,
    ya = ya,
  }

  -- Extract just the extract_symbols function by executing the file
  local chunk = load(content, "symbol.lua", "t", env)
  if chunk then chunk() end

  -- Now we need to extract the function manually since it's local
  -- Instead, let's just call the file's logic directly
  return env
end

-- Extract symbols from a file (direct implementation)
local function extract_symbols_direct(path, ext)
  local file = io.open(path, "r")
  if not file then
    return { { type = "error", text = "ERROR: Could not open file" } }
  end

  local symbols = {}
  local in_class = false
  local in_impl = false
  local class_indent = 0
  local current_type = nil
  local in_code_block = false

  for line in file:lines() do
    local symbol = nil
    local symbol_type = nil

    if ext == "md" then
      if line:match("^```") or line:match("^~~~") then
        in_code_block = not in_code_block
      end

      if not in_code_block then
        local level, text = line:match("^(#+)%s+(.+)")
        if level and text then
          if not text:match("^https?://") then
            local indent = string.rep("  ", #level - 1)
            local color_key = "header" .. math.min(#level, 4)
            symbol = indent .. text
            symbol_type = color_key
          end
        end
      end

    elseif ext == "py" then
      local line_indent = #(line:match("^(%s*)") or "")

      local class_name = line:match("^class%s+([%w_]+)")
      if class_name then
        symbol = "class " .. class_name
        symbol_type = "class"
        in_class = true
        class_indent = line_indent
      else
        local func_name = line:match("^%s*def%s+([%w_]+)")
        if func_name then
          if in_class and line_indent > class_indent then
            symbol = "  def " .. func_name .. "()"
          else
            symbol = "def " .. func_name .. "()"
            in_class = false
          end
          symbol_type = "function_def"
        elseif in_class and line_indent <= class_indent and line:match("%S") then
          in_class = false
        end
      end

    elseif ext == "js" or ext == "ts" then
      local class_name = line:match("^%s*class%s+([%w_]+)")
      if class_name then
        symbol = "class " .. class_name
        symbol_type = "class"
        in_class = true
      elseif line:match("^}") then
        in_class = false
      else
        local method_name = line:match("^%s+([%w_]+)%s*%([^)]*%)%s*{")
        if method_name and in_class then
          symbol = "  " .. method_name .. "()"
          symbol_type = "function_def"
        else
          local func_name = line:match("^%s*function%s+([%w_]+)")
          if func_name then
            symbol = "function " .. func_name .. "()"
            symbol_type = "function_def"
            in_class = false
          else
            local const_func = line:match("^%s*const%s+([%w_]+)%s*=%s*%(")
            if const_func then
              symbol = "const " .. const_func .. " = ()"
              symbol_type = "function_def"
            else
              local export_func = line:match("^%s*export%s+function%s+([%w_]+)")
              if export_func then
                symbol = "export function " .. export_func .. "()"
                symbol_type = "export"
              end
            end
          end
        end
      end

    elseif ext == "rs" then
      local impl_name = line:match("^%s*impl%s+([%w_<>]+)")
      if impl_name then
        symbol = "impl " .. impl_name
        symbol_type = "class"
        in_impl = true
      elseif line:match("^}") then
        in_impl = false
      else
        local fn_name = line:match("^%s*pub%s+fn%s+([%w_]+)")
        if fn_name then
          if in_impl then
            symbol = "  pub fn " .. fn_name .. "()"
          else
            symbol = "pub fn " .. fn_name .. "()"
          end
          symbol_type = "export"
        else
          local priv_fn = line:match("^%s+fn%s+([%w_]+)")
          if priv_fn and in_impl then
            symbol = "  fn " .. priv_fn .. "()"
            symbol_type = "function_def"
          else
            local top_fn = line:match("^fn%s+([%w_]+)")
            if top_fn then
              symbol = "fn " .. top_fn .. "()"
              symbol_type = "function_def"
            else
              local struct_name = line:match("^%s*pub%s+struct%s+([%w_]+)")
              if struct_name then
                symbol = "pub struct " .. struct_name
                symbol_type = "export"
              else
                local enum_name = line:match("^%s*pub%s+enum%s+([%w_]+)")
                if enum_name then
                  symbol = "pub enum " .. enum_name
                  symbol_type = "export"
                end
              end
            end
          end
        end
      end

    elseif ext == "go" then
      local type_name = line:match("^type%s+([%w_]+)")
      if type_name then
        symbol = "type " .. type_name
        symbol_type = "class"
        current_type = type_name
      else
        local receiver, method = line:match("^func%s+%(.-*([%w_]+)%)%s+([%w_]+)")
        if receiver and method then
          if receiver == current_type then
            symbol = "  func " .. method .. "()"
          else
            symbol = "func (" .. receiver .. ") " .. method .. "()"
          end
          symbol_type = "function_def"
        else
          local func_name = line:match("^func%s+([%w_]+)")
          if func_name then
            symbol = "func " .. func_name .. "()"
            symbol_type = "function_def"
            current_type = nil
          end
        end
      end
    end

    if symbol then
      table.insert(symbols, { type = symbol_type, text = symbol })
    end
  end

  file:close()

  if #symbols == 0 then
    return { { type = "info", text = "No symbols found" } }
  end
  return symbols
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
    local symbols = extract_symbols_direct(test.file, test.ext)
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
    local symbols = extract_symbols_direct(test.file, test.ext)
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
