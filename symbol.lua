--- @sync peek
local M = {}

-- Style mapping from user's theme
-- Maps symbol types to yazi theme styles (no fallbacks needed - theme always provides these)
local function get_styles()
	return {
		-- Headers use permission colors (visual hierarchy matches file permissions)
		header1 = th.status.perm_exec,    -- Green (execute permission)
		header2 = th.status.perm_write,   -- Red (write permission)
		header3 = th.status.perm_read,    -- Yellow (read permission)
		header4 = th.status.perm_type,    -- Blue (file type)

		-- Code symbols use semantic UI colors
		class = th.which.cand,            -- Cyan (command candidates)
		function_def = th.status.perm_type, -- Blue (file type)
		export = th.pick.active,          -- Mauve/pink (active selection)
	}
end

-- ============================================================================
-- EXTRACTOR INTERFACE
-- ============================================================================
-- Each extractor function implements symbol extraction for one language.
--
-- Interface:
--   - Input: file handle (from io.open)
--   - Output: array of symbols: { {type = "symbol_type", text = "display"}, ... }
--   - Symbol types: "header1-4", "class", "function_def", "export"
--
-- To add a new language:
--   1. Write an extractor function following this interface
--   2. Add file extension(s) to EXTRACTORS registry below
--   3. Test with sample files
-- ============================================================================

-- MARKDOWN EXTRACTOR
-- Extracts headers (H1-H4) with hierarchical indentation
-- Ignores headers inside code blocks and URLs
local function extract_md(file)
	local symbols = {}
	local in_code_block = false

	for line in file:lines() do
		-- Track code blocks (fenced with ``` or ~~~)
		if line:match("^```") or line:match("^~~~") then
			in_code_block = not in_code_block
		end

		-- Only extract headers if NOT inside a code block
		if not in_code_block then
			local level, text = line:match("^(#+)%s+(.+)")
			if level and text then
				-- Skip headers that are URLs (start with http:// or https://)
				if not text:match("^https?://") then
					local indent = string.rep("  ", #level - 1)
					local color_key = "header" .. math.min(#level, 4)
					table.insert(symbols, { type = color_key, text = indent .. text })
				end
			end
		end
	end

	return symbols
end

-- PYTHON EXTRACTOR
-- Extracts classes and functions with proper nesting via indentation tracking
local function extract_py(file)
	local symbols = {}
	local in_class = false
	local class_indent = 0

	for line in file:lines() do
		local line_indent = #(line:match("^(%s*)") or "")

		-- Check for class definition
		local class_name = line:match("^class%s+([%w_]+)")
		if class_name then
			table.insert(symbols, { type = "class", text = "class " .. class_name })
			in_class = true
			class_indent = line_indent
		else
			-- Check for function/method definition
			local func_name = line:match("^%s*def%s+([%w_]+)")
			if func_name then
				-- If indented more than class, it's a method
				if in_class and line_indent > class_indent then
					table.insert(symbols, { type = "function_def", text = "  def " .. func_name .. "()" })
				else
					table.insert(symbols, { type = "function_def", text = "def " .. func_name .. "()" })
					in_class = false  -- Top-level function, exit class context
				end
			elseif in_class and line_indent <= class_indent and line:match("%S") then
				-- Non-empty line at class level or less - exit class context
				in_class = false
			end
		end
	end

	return symbols
end

-- JAVASCRIPT/TYPESCRIPT EXTRACTOR
-- Extracts classes, methods, functions, and exports
-- Tracks class context with closing braces
local function extract_js(file)
	local symbols = {}
	local in_class = false

	for line in file:lines() do
		-- Check for class definition
		local class_name = line:match("^%s*class%s+([%w_]+)")
		if class_name then
			table.insert(symbols, { type = "class", text = "class " .. class_name })
			in_class = true
		elseif line:match("^}") then
			in_class = false  -- Exit class on closing brace at start of line
		else
			-- Method inside class (indented, no 'function' keyword)
			local method_name = line:match("^%s+([%w_]+)%s*%([^)]*%)%s*{")
			if method_name and in_class then
				table.insert(symbols, { type = "function_def", text = "  " .. method_name .. "()" })
			else
				-- Top-level function
				local func_name = line:match("^%s*function%s+([%w_]+)")
				if func_name then
					table.insert(symbols, { type = "function_def", text = "function " .. func_name .. "()" })
					in_class = false
				else
					-- Arrow function (const name = (...) =>)
					local const_func = line:match("^%s*const%s+([%w_]+)%s*=%s*%(")
					if const_func then
						table.insert(symbols, { type = "function_def", text = "const " .. const_func .. " = ()" })
					else
						-- Exported function
						local export_func = line:match("^%s*export%s+function%s+([%w_]+)")
						if export_func then
							table.insert(symbols, { type = "export", text = "export function " .. export_func .. "()" })
						end
					end
				end
			end
		end
	end

	return symbols
end

-- RUST EXTRACTOR
-- Extracts structs, enums, impl blocks, and functions
-- Tracks impl context for method nesting
local function extract_rs(file)
	local symbols = {}
	local in_impl = false

	for line in file:lines() do
		-- Check for impl block
		local impl_name = line:match("^%s*impl%s+([%w_<>]+)")
		if impl_name then
			table.insert(symbols, { type = "class", text = "impl " .. impl_name })
			in_impl = true
		elseif line:match("^}") then
			in_impl = false  -- Exit impl block
		else
			-- Public function
			local fn_name = line:match("^%s*pub%s+fn%s+([%w_]+)")
			if fn_name then
				if in_impl then
					table.insert(symbols, { type = "export", text = "  pub fn " .. fn_name .. "()" })
				else
					table.insert(symbols, { type = "export", text = "pub fn " .. fn_name .. "()" })
				end
			else
				-- Private function in impl
				local priv_fn = line:match("^%s+fn%s+([%w_]+)")
				if priv_fn and in_impl then
					table.insert(symbols, { type = "function_def", text = "  fn " .. priv_fn .. "()" })
				else
					-- Top-level function
					local top_fn = line:match("^fn%s+([%w_]+)")
					if top_fn then
						table.insert(symbols, { type = "function_def", text = "fn " .. top_fn .. "()" })
					else
						-- Struct
						local struct_name = line:match("^%s*pub%s+struct%s+([%w_]+)")
						if struct_name then
							table.insert(symbols, { type = "export", text = "pub struct " .. struct_name })
						else
							-- Enum
							local enum_name = line:match("^%s*pub%s+enum%s+([%w_]+)")
							if enum_name then
								table.insert(symbols, { type = "export", text = "pub enum " .. enum_name })
							end
						end
					end
				end
			end
		end
	end

	return symbols
end

-- GO EXTRACTOR
-- Extracts types, functions, and methods
-- Nests methods under their receiver types
local function extract_go(file)
	local symbols = {}
	local current_type = nil

	for line in file:lines() do
		-- Check for type definition
		local type_name = line:match("^type%s+([%w_]+)")
		if type_name then
			table.insert(symbols, { type = "class", text = "type " .. type_name })
			current_type = type_name
		else
			-- Method with receiver
			local receiver, method = line:match("^func%s+%(.-*([%w_]+)%)%s+([%w_]+)")
			if receiver and method then
				-- Method with receiver - nest under type if it matches
				if receiver == current_type then
					table.insert(symbols, { type = "function_def", text = "  func " .. method .. "()" })
				else
					table.insert(symbols, { type = "function_def", text = "func (" .. receiver .. ") " .. method .. "()" })
				end
			else
				-- Top-level function
				local func_name = line:match("^func%s+([%w_]+)")
				if func_name then
					table.insert(symbols, { type = "function_def", text = "func " .. func_name .. "()" })
					current_type = nil  -- Top-level function, clear type context
				end
			end
		end
	end

	return symbols
end

-- ============================================================================
-- EXTRACTOR REGISTRY
-- ============================================================================
-- Maps file extensions to extractor functions.
--
-- To add support for a new language:
--   1. Write an extractor function following the interface above
--   2. Add the file extension(s) here pointing to your extractor
--   3. Add test fixtures to verify correct extraction
-- ============================================================================

local EXTRACTORS = {
	md = extract_md,
	py = extract_py,
	js = extract_js,
	ts = extract_js,
	jsx = extract_js,
	tsx = extract_js,
	mjs = extract_js,
	rs = extract_rs,
	go = extract_go,
}

-- ============================================================================
-- MAIN PLUGIN LOGIC
-- ============================================================================

-- Extract symbols from a file using the appropriate extractor
local function extract_symbols(path, ext)
	local extractor = EXTRACTORS[ext]
	if not extractor then
		return { { type = "info", text = "No extractor for ." .. ext } }
	end

	local file = io.open(path, "r")
	if not file then
		return { { type = "error", text = "Could not open file" } }
	end

	local symbols = extractor(file)
	file:close()

	if #symbols == 0 then
		return { { type = "info", text = "No symbols found" } }
	end

	return symbols
end

-- Yazi peek function - called when previewing a file
function M:peek(job)
	local url_str = tostring(job.file.url)
	local ext = url_str:match("%.([^./]+)$")

	if not ext then
		return require("empty"):peek(job)
	end

	-- Extract the file path (remove file:// prefix if present)
	local path = url_str:gsub("^file://", "")

	local symbols = extract_symbols(path, ext)
	local styles = get_styles()

	-- Create styled text lines using theme styles
	local lines = {}
	for _, sym in ipairs(symbols) do
		local style = styles[sym.type] or ui.Style()
		local span = ui.Span(sym.text):style(style)
		table.insert(lines, ui.Line { span })
	end

	ya.preview_widget(job, { ui.Text(lines):area(job.area) })
end

-- Yazi seek function - handle scrolling (no-op for symbol view)
function M:seek() end

-- Expose for testing (not used by yazi)
M._extract_symbols = extract_symbols

return M
