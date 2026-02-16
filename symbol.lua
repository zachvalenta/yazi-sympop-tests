--- @sync peek
local M = {}

-- Catppuccin Mocha color scheme
local COLORS = {
	header1 = "#f38ba8",      -- Red - Top level headers
	header2 = "#fab387",      -- Peach - Second level headers
	header3 = "#f9e2af",      -- Yellow - Third level headers
	header4 = "#a6e3a1",      -- Green - Fourth level headers
	class = "#f9e2af",        -- Yellow - Classes, structs, enums, types
	function_def = "#89b4fa", -- Blue - Functions, methods
	export = "#cba6f7",       -- Mauve - Exports, public items
}

-- Extract symbols with type information for coloring and nesting
local function extract_symbols(path, ext)
	local file = io.open(path, "r")
	if not file then
		return { { type = "error", text = "ERROR: Could not open file" } }
	end

	local symbols = {}
	local in_class = false  -- Track if we're inside a class
	local in_impl = false   -- Track if we're inside a Rust impl block
	local class_indent = 0  -- Track indentation level of current class (for Python)
	local current_type = nil -- Track current Go type for methods
	local in_code_block = false -- Track if we're inside a markdown code block

	for line in file:lines() do
		local symbol = nil
		local symbol_type = nil

		if ext == "md" then
			-- Track code blocks (fenced with ``` or ~~~)
			if line:match("^```") or line:match("^~~~") then
				in_code_block = not in_code_block
			end

			-- Only extract headers if we're NOT inside a code block
			if not in_code_block then
				local level, text = line:match("^(#+)%s+(.+)")
				if level and text then
					-- Skip headers that are URLs (start with http:// or https://)
					if not text:match("^https?://") then
						local indent = string.rep("  ", #level - 1)
						local color_key = "header" .. math.min(#level, 4)
						symbol = indent .. text
						symbol_type = color_key
					end
				end
			end

		elseif ext == "py" then
			-- Python: Track class context via indentation
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
					-- If indented more than class, it's a method
					if in_class and line_indent > class_indent then
						symbol = "  def " .. func_name .. "()"
					else
						symbol = "def " .. func_name .. "()"
						in_class = false  -- Top-level function, exit class context
					end
					symbol_type = "function_def"
				elseif in_class and line_indent <= class_indent and line:match("%S") then
					-- Non-empty line at class level or less - exit class context
					in_class = false
				end
			end

		elseif ext == "lua" then
			-- Lua: Simple table method detection
			local table_method = line:match("^%s*function%s+([%w_]+):([%w_]+)")
			if table_method then
				symbol = "function " .. table_method .. "()"
				symbol_type = "function_def"
			else
				local func_name = line:match("^%s*function%s+([%w_]+)")
				if func_name then
					symbol = "function " .. func_name .. "()"
					symbol_type = "function_def"
				else
					local local_func = line:match("^%s*local%s+function%s+([%w_]+)")
					if local_func then
						symbol = "local function " .. local_func .. "()"
						symbol_type = "function_def"
					end
				end
			end

		elseif ext == "js" or ext == "ts" or ext == "jsx" or ext == "tsx" or ext == "mjs" then
			-- JavaScript/TypeScript: Track class context with braces
			local class_name = line:match("^%s*class%s+([%w_]+)")
			if class_name then
				symbol = "class " .. class_name
				symbol_type = "class"
				in_class = true
			elseif line:match("^}") then
				in_class = false  -- Exit class on closing brace at start of line
			else
				-- Method inside class (indented, no 'function' keyword)
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
			-- Rust: Track impl blocks
			local impl_name = line:match("^%s*impl%s+([%w_<>]+)")
			if impl_name then
				symbol = "impl " .. impl_name
				symbol_type = "class"
				in_impl = true
			elseif line:match("^}") then
				in_impl = false  -- Exit impl block
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
			-- Go: Track types and nest methods under them
			local type_name = line:match("^type%s+([%w_]+)")
			if type_name then
				symbol = "type " .. type_name
				symbol_type = "class"
				current_type = type_name
			else
				local receiver, method = line:match("^func%s+%(.-*([%w_]+)%)%s+([%w_]+)")
				if receiver and method then
					-- Method with receiver - nest under type if it matches
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
						current_type = nil  -- Top-level function, clear type context
					end
				end
			end

		elseif ext == "rb" then
			-- Ruby: Track class context
			local class_name = line:match("^%s*class%s+([%w_:]+)")
			if class_name then
				symbol = "class " .. class_name
				symbol_type = "class"
				in_class = true
			elseif line:match("^end") then
				in_class = false  -- Exit class on 'end' at start of line
			else
				local method_name = line:match("^%s+def%s+([%w_?!]+)")
				if method_name and in_class then
					symbol = "  def " .. method_name
					symbol_type = "function_def"
				else
					local top_method = line:match("^def%s+([%w_?!]+)")
					if top_method then
						symbol = "def " .. top_method
						symbol_type = "function_def"
						in_class = false
					end
				end
			end

		elseif ext == "sh" or ext == "bash" or ext == "zsh" then
			-- Shell functions (typically flat, no nesting)
			local func_name = line:match("^([%w_]+)%(%)")
			if func_name then
				symbol = "function " .. func_name .. "()"
				symbol_type = "function_def"
			else
				local func_keyword = line:match("^function%s+([%w_]+)")
				if func_keyword then
					symbol = "function " .. func_keyword .. "()"
					symbol_type = "function_def"
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

function M:peek(job)
	local url_str = tostring(job.file.url)
	local ext = url_str:match("%.([^./]+)$")

	if not ext then
		return require("empty"):peek(job)
	end

	-- Extract the file path (remove file:// prefix if present)
	local path = url_str:gsub("^file://", "")

	local symbols = extract_symbols(path, ext)

	-- Create colored text lines
	local lines = {}
	for _, sym in ipairs(symbols) do
		local color = COLORS[sym.type] or "white"
		local span = ui.Span(sym.text):style(ui.Style():fg(color))
		table.insert(lines, ui.Line { span })
	end

	ya.preview_widget(job, { ui.Text(lines):area(job.area) })
end

function M:seek() end

return M
