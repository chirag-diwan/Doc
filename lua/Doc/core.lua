local m = {}

---@class Keymap
---@field openauto string
---@field open string

---@class Config
---@field enabled boolean
---@field keymaps Keymap

local defaults = {
  enabled = true,
  keymaps = {
    openauto = "<leader>da",
    open = "<leader>do",
  },
}

-- Dynamic Highlights
local function set_highlights()
  -- 1. Main Transparent Background (Crucial for the "see-through" look)
  vim.api.nvim_set_hl(0, "DocsTransparent", { bg = "NONE", default = true })

  -- 2. Selection Highlight (Uses your theme's Popup Menu Selection)
  vim.api.nvim_set_hl(0, "DocsSel", { link = "PmenuSel", default = true })

  -- 3. Border: Try to grab the theme's border color, but FORCE background to NONE
  local border_hl = vim.api.nvim_get_hl(0, { name = "FloatBorder", link = false })
  -- Fallback to 'Normal' foreground if FloatBorder isn't set, ensuring visibility
  local border_fg = border_hl.fg or vim.api.nvim_get_hl(0, { name = "Normal" }).fg
  vim.api.nvim_set_hl(0, "DocsBorder", { fg = border_fg, bg = "NONE", default = true })

  -- 4. Text Highlights
  vim.api.nvim_set_hl(0, "DocsTitle", { link = "FloatTitle", default = true })
  vim.api.nvim_set_hl(0, "DocsType", { link = "Type", default = true })
  vim.api.nvim_set_hl(0, "DocsName", { link = "Function", default = true })
end

function m.move_cursor(delta)
  local max = #m.current_list
  if max == 0 then return end

  m.cursor = math.max(1, math.min(m.cursor + delta, max))

  if m.resultWin and vim.api.nvim_win_is_valid(m.resultWin) then
    vim.api.nvim_win_set_cursor(m.resultWin, { m.cursor, 0 })
  end
end

local function merge_config(user)
  user = user or {}
  return vim.tbl_deep_extend("force", defaults, user)
end

---@param config Config
function m.setup(config)
  config = merge_config(config)
  if not config.enabled then return end

  set_highlights()

  -- Ensure highlights stick even if colorscheme changes
  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = set_highlights,
  })

  m.config = config
  m.cursor = 1
  m.namespace = vim.api.nvim_create_namespace("doc_namespace")
  m.indices = vim.fn.GetIndices("js", "OnDataReceived")
  m.current_list = m.indices.entries or {}
  m.prompt = ""
  m.prevPromptLen = 0

  vim.keymap.set("n", config.keymaps.openauto, function() m.makeWindows() end, { desc = "Docs: open auto" })
  vim.keymap.set("n", config.keymaps.open, function() m.makeWindows() end, { desc = "Docs: open" })
end

function m.openDescription(obj)
  local description = vim.fn.GetPath(obj.path)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, description)

  vim.api.nvim_command("split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
end

function m.update()
  if m.prompt == "" then
    m.current_list = m.indices.entries or {}
  else
    local new_matches = {}
    if m.indices and m.indices.entries then
      for _, value in pairs(m.indices.entries) do
        if string.find(string.lower(value.name), string.lower(m.prompt), 1, true) then
          table.insert(new_matches, value)
        end
      end
      m.current_list = new_matches
    end
  end

  if m.promptWin and vim.api.nvim_win_is_valid(m.promptWin) then
    local total = m.indices.entries and #m.indices.entries or 0
    local current = #m.current_list
    local title = string.format("  Filter [%d/%d] ", current, total)
    vim.api.nvim_win_set_config(m.promptWin, { title = title, title_pos = "center" })
  end

  m.cursor = math.min(m.cursor, #m.current_list)
  if m.cursor < 1 then m.cursor = 1 end

  if m.resultWin and vim.api.nvim_win_is_valid(m.resultWin) then
    pcall(vim.api.nvim_win_set_cursor, m.resultWin, { m.cursor, 0 })
  end
end

local function close_windows()
  if m.promptWin and vim.api.nvim_win_is_valid(m.promptWin) then
    vim.api.nvim_win_close(m.promptWin, true)
  end
  if m.resultWin and vim.api.nvim_win_is_valid(m.resultWin) then
    vim.api.nvim_win_close(m.resultWin, true)
  end
end

function m.makeWindows()
  -- INCREASED SIZE
  local width = 80
  local height = 25

  local ui = vim.api.nvim_list_uis()[1]
  local row = math.floor((ui.height - height) / 2) - 2
  local col = math.floor((ui.width - width) / 2)

  m.resultBuf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(m.resultBuf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(m.resultBuf, 'buftype', 'nofile')

  m.promptBuf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(m.promptBuf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(m.promptBuf, 'buftype', 'nofile')

  local common_opts = {
    relative = "editor",
    width = width,
    col = col,
    style = "minimal",
    border = "rounded",
  }

  local resultOpts = vim.tbl_extend("force", common_opts, {
    height = height,
    row = row,
    title = " Documentation ",
    title_pos = "center",
    focusable = false,
  })

  m.resultWin = vim.api.nvim_open_win(m.resultBuf, false, resultOpts)

  local promptOpts = vim.tbl_extend("force", common_opts, {
    height = 1,
    row = row + height + 2,
    title = "  Filter ",
    title_pos = "center",
    focusable = true,
  })

  m.promptWin = vim.api.nvim_open_win(m.promptBuf, true, promptOpts)

  -- UI Styling: Apply 'DocsTransparent' to Normal to make background see-through
  local winhl_result = "Normal:DocsTransparent,FloatBorder:DocsBorder,CursorLine:DocsSel,FloatTitle:DocsTitle"
  local winhl_prompt = "Normal:DocsTransparent,FloatBorder:DocsBorder,FloatTitle:DocsTitle"

  vim.api.nvim_win_set_option(m.resultWin, "winhl", winhl_result)
  vim.api.nvim_win_set_option(m.resultWin, "cursorline", true)
  vim.api.nvim_win_set_option(m.resultWin, "cursorlineopt", "line")
  vim.api.nvim_win_set_option(m.resultWin, "wrap", false)
  vim.api.nvim_win_set_option(m.resultWin, "scrolloff", 2)

  vim.api.nvim_win_set_option(m.promptWin, "winhl", winhl_prompt)

  m.setIndices()
  m.cursor = 1

  if #m.current_list > 0 then
    pcall(vim.api.nvim_win_set_cursor, m.resultWin, { 1, 0 })
  end

  vim.cmd('startinsert')

  local map_opts = { buffer = m.promptBuf, nowait = true }
  vim.keymap.set("i", "<Down>", function() m.move_cursor(1) end, map_opts)
  vim.keymap.set("i", "<Up>", function() m.move_cursor(-1) end, map_opts)
  vim.keymap.set("i", "<C-n>", function() m.move_cursor(1) end, map_opts)
  vim.keymap.set("i", "<C-p>", function() m.move_cursor(-1) end, map_opts)
  vim.keymap.set("i", "<CR>", function()
    if m.current_list[m.cursor] then
      m.openDescription(m.current_list[m.cursor])
    end
  end, map_opts)

  vim.keymap.set("n", "<Esc>", close_windows, map_opts)
  vim.keymap.set("i", "<Esc>", close_windows, map_opts)

  vim.api.nvim_create_autocmd("WinClosed", {
    buffer = m.promptBuf,
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(m.resultWin) then
        vim.api.nvim_win_close(m.resultWin, true)
      end
    end
  })

  vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = m.promptBuf,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(m.promptBuf, 0, -1, true)
      m.prompt = table.concat(lines, " ")
      m.update()
      m.setIndices()
    end
  })
end

function m.setIndices()
  if not m.resultBuf or not vim.api.nvim_buf_is_valid(m.resultBuf) then return end

  vim.api.nvim_buf_set_lines(m.resultBuf, 0, -1, false, {})
  vim.api.nvim_buf_clear_namespace(m.resultBuf, m.namespace, 0, -1)

  if not m.current_list or #m.current_list == 0 then
    local msg = "  No results found"
    vim.api.nvim_buf_set_lines(m.resultBuf, 0, -1, false, { msg })
    vim.api.nvim_buf_add_highlight(m.resultBuf, m.namespace, "Comment", 0, 0, -1)
    return
  end

  local linesList = {}

  for _, value in pairs(m.current_list) do
    table.insert(linesList, " " .. (value.name or ""))
  end

  vim.api.nvim_buf_set_lines(m.resultBuf, 0, -1, false, linesList)

  for i, value in ipairs(m.current_list) do
    local line_idx = i - 1
    local name = value.name or ""
    local type_str = value.type or ""

    vim.api.nvim_buf_add_highlight(m.resultBuf, m.namespace, "DocsName", line_idx, 1, #name + 1)

    if type_str ~= "" then
      vim.api.nvim_buf_set_extmark(m.resultBuf, m.namespace, line_idx, 0, {
        virt_text = { { type_str, "DocsType" }, { " ", "None" } },
        virt_text_pos = "right_align",
      })
    end
  end
end

return m
