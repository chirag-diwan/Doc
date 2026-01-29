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

function m.move_cursor(delta)
  local max = #m.current_list
  if max == 0 then
    return
  end

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

  if not config.enabled then
    return
  end

  m.config = config
  m.cursor = 1
  m.namespace = vim.api.nvim_create_namespace("doc_namespace")
  m.indices = vim.fn.GetIndices("js", "OnDataReceived")
  m.current_list = m.indices.entries or {}
  m.prompt = ""
  m.prevPromptLen = 0

  vim.keymap.set("n", config.keymaps.openauto, function()
    m.makeWindows()
  end, { desc = "Docs: open auto" })

  vim.keymap.set("n", config.keymaps.open, function()
    m.makeWindows()
  end, { desc = "Docs: open" })
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
    local title = string.format(" Filter (%d/%d) ", current, total)
    vim.api.nvim_win_set_config(m.promptWin, { title = title, title_pos = "center" })
  end

  m.cursor = math.min(m.cursor, #m.current_list)
  if m.cursor < 1 then
    m.cursor = 1
  end

  if m.resultWin and vim.api.nvim_win_is_valid(m.resultWin) then
    vim.api.nvim_win_set_cursor(m.resultWin, { m.cursor, 0 })
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
  local width = 60
  local height = 20
  local border_style = "rounded"
  local ui = vim.api.nvim_list_uis()[1]
  local row = math.floor((ui.height - height) / 2)
  local col = math.floor((ui.width - width) / 2)

  m.resultBuf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(m.resultBuf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(m.resultBuf, 'buftype', 'nofile')
  m.promptBuf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(m.promptBuf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(m.promptBuf, 'buftype', 'nofile')

  local resultOpts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = border_style,
    title = " Documentation ",
    title_pos = "center",
  }
  m.resultWin = vim.api.nvim_open_win(m.resultBuf, false, resultOpts)

  local promptOpts = {
    relative = "editor",
    width = width,
    height = 1,
    row = row + height + 2,
    col = col,
    style = "minimal",
    border = border_style,
    title = " Filter ",
    title_pos = "center",
  }

  m.promptWin = vim.api.nvim_open_win(m.promptBuf, true, promptOpts)


  local win_highlights = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual"

  vim.api.nvim_win_set_option(m.resultWin, "winblend", 10)
  vim.api.nvim_win_set_option(m.resultWin, "winhl", win_highlights)
  vim.api.nvim_win_set_option(m.resultWin, "cursorline", true)
  vim.api.nvim_win_set_option(m.resultWin, "cursorlineopt", "both")
  vim.api.nvim_win_set_option(m.resultWin, "wrap", false)

  vim.api.nvim_win_set_option(m.promptWin, "winblend", 10)
  vim.api.nvim_win_set_option(m.promptWin, "winhl", win_highlights)

  m.setIndices()
  m.cursor = 1

  if #m.current_list > 0 then
    vim.api.nvim_win_set_cursor(m.resultWin, { 1, 0 })
  end

  vim.cmd('startinsert')

  vim.keymap.set("i", "<Down>", function() m.move_cursor(1) end, { buffer = m.promptBuf, nowait = true })
  vim.keymap.set("i", "<Up>", function() m.move_cursor(-1) end, { buffer = m.promptBuf, nowait = true })
  vim.keymap.set("i", "<C-n>", function() m.move_cursor(1) end, { buffer = m.promptBuf, nowait = true })
  vim.keymap.set("i", "<C-p>", function() m.move_cursor(-1) end, { buffer = m.promptBuf, nowait = true })
  vim.keymap.set("i", "<CR>", function() m.openDescription(m.current_list[m.cursor]) end,
    { buffer = m.promptBuf, nowait = true })

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

  vim.keymap.set("n", "<Esc>", close_windows, { buffer = m.promptBuf, nowait = true })
  vim.keymap.set("n", "<Esc>", close_windows, { buffer = m.resultBuf, nowait = true })
  vim.keymap.set("i", "<Esc>", close_windows, { buffer = m.promptBuf, nowait = true })
end

function m.setIndices()
  if not m.resultBuf or not vim.api.nvim_buf_is_valid(m.resultBuf) then return end


  vim.api.nvim_buf_clear_namespace(m.resultBuf, m.namespace, 0, -1)

  local linesList = {}
  local display_entries = {}


  local win_width = vim.api.nvim_win_get_width(m.resultWin)

  local content_width = win_width - 2

  if m.current_list then
    for _, value in pairs(m.current_list) do
      local name = value.name or ""
      local type_str = value.type or ""



      local space_count = content_width - #name - #type_str
      if space_count < 1 then space_count = 1 end

      local line = string.format("%s%s%s", name, string.rep(" ", space_count), type_str)
      table.insert(linesList, line)
      table.insert(display_entries, { name_len = #name, type_len = #type_str, padding = space_count })
    end
  end

  vim.api.nvim_buf_set_lines(m.resultBuf, 0, -1, false, linesList)


  for i, info in ipairs(display_entries) do
    local line_idx = i - 1

    vim.api.nvim_buf_add_highlight(m.resultBuf, m.namespace, "Function", line_idx, 0, info.name_len)


    local type_start = info.name_len + info.padding
    local type_end = type_start + info.type_len
    vim.api.nvim_buf_add_highlight(m.resultBuf, m.namespace, "Comment", line_idx, type_start, type_end)
  end
end

return m
