local M = {}

---@class Config
local defaults = {
  enabled = true,
  keymaps = {
    openauto = "<leader>da",
    open = "<leader>do",
    openlocal = "<leader>dl",
    createdoc = "<leader>dc"
  },
  localDir = vim.fn.stdpath("data") .. "/site/docs/",
}

local state = {
  config = {},
  ns = vim.api.nvim_create_namespace("doc_plugin"),
  current_list = {},
  cursor = 1,
  prompt = "",
  is_local = false,
  indices = { entries = {} },
  windows = { prompt = nil, result = nil },
  buffers = { prompt = nil, result = nil },
}

local function scan_local_dir(path)
  local entries = {}
  local handle = vim.loop.fs_scandir(path)
  if not handle then return entries end

  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then break end
    local full_path = path .. "/" .. name
    if type == "directory" then
      local sub = scan_local_dir(full_path)
      vim.list_extend(entries, sub)
    else
      table.insert(entries, { name = name, path = full_path, type = "file" })
    end
  end
  return entries
end

local function set_highlights()
  local colors = {
    DocsTransparent = { bg = "NONE", default = true },
    DocsSel         = { link = "PmenuSel", default = true },
    DocsBorder      = { link = "FloatBorder", default = true },
    DocsTitle       = { link = "FloatTitle", default = true },
    DocsType        = { link = "Type", default = true },
    DocsName        = { link = "Function", default = true },
    DocsComment     = { link = "Comment", default = true },
  }
  for name, opts in pairs(colors) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end

function M.render_results()
  if not state.buffers.result or not vim.api.nvim_buf_is_valid(state.buffers.result) then return end

  vim.api.nvim_buf_clear_namespace(state.buffers.result, state.ns, 0, -1)

  if #state.current_list == 0 then
    vim.api.nvim_buf_set_lines(state.buffers.result, 0, -1, false, { "  No results found" })
    return
  end

  local lines = {}
  for _, entry in ipairs(state.current_list) do
    table.insert(lines, string.format("  %s", entry.name or "Unknown"))
  end

  vim.api.nvim_buf_set_lines(state.buffers.result, 0, -1, false, lines)

  for i, entry in ipairs(state.current_list) do
    local idx = i - 1
    vim.api.nvim_buf_add_highlight(state.buffers.result, state.ns, "DocsName", idx, 2, -1)
    if entry.type then
      vim.api.nvim_buf_set_extmark(state.buffers.result, state.ns, idx, 0, {
        virt_text = { { entry.type, "DocsType" } },
        virt_text_pos = "right_align",
      })
    end
  end
end

function M.filter_list()
  local all = state.is_local and scan_local_dir(state.config.localDir) or state.indices.entries

  if state.prompt == "" then
    state.current_list = all
  else
    state.current_list = vim.tbl_filter(function(item)
      return item.name:lower():find(state.prompt:lower(), 1, true) ~= nil
    end, all)
  end

  state.cursor = math.min(math.max(1, state.cursor), #state.current_list)
  M.render_results()

  if state.windows.result and vim.api.nvim_win_is_valid(state.windows.result) then
    pcall(vim.api.nvim_win_set_cursor, state.windows.result, { state.cursor, 0 })
  end
end

function M.open_picker(is_local)
  state.is_local = is_local
  state.prompt = ""
  state.cursor = 1


  state.buffers.result = vim.api.nvim_create_buf(false, true)
  state.buffers.prompt = vim.api.nvim_create_buf(false, true)

  local width = math.floor(vim.o.columns * 0.7)
  local height = 15

  state.windows.result = vim.api.nvim_open_win(state.buffers.result, false, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " Documentation ",
    title_pos = "center",
  })

  state.windows.prompt = vim.api.nvim_open_win(state.buffers.prompt, true, {
    relative = "editor",
    width = width,
    height = 1,
    row = math.floor((vim.o.lines - height) / 2) + height + 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " Filter ",
  })


  vim.wo[state.windows.result].cursorline = true
  vim.wo[state.windows.result].winhl = "Normal:DocsTransparent,FloatBorder:DocsBorder"
  vim.wo[state.windows.prompt].winhl = "Normal:DocsTransparent,FloatBorder:DocsBorder"

  local opts = { buffer = state.buffers.prompt, silent = true }
  vim.keymap.set("i", "<C-n>", function() M.move_cursor(1) end, opts)
  vim.keymap.set("i", "<C-p>", function() M.move_cursor(-1) end, opts)
  vim.keymap.set("i", "<CR>", M.confirm_selection, opts)
  vim.keymap.set({ "i", "n" }, "<Esc>", M.close, opts)


  vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = state.buffers.prompt,
    callback = function()
      state.prompt = vim.api.nvim_buf_get_lines(state.buffers.prompt, 0, 1, false)[1] or ""
      M.filter_list()
    end,
  })

  M.filter_list()
  vim.cmd("startinsert")
end

function M.move_cursor(delta)
  state.cursor = math.max(1, math.min(state.cursor + delta, #state.current_list))
  pcall(vim.api.nvim_win_set_cursor, state.windows.result, { state.cursor, 0 })
end

function M.confirm_selection()
  local selected = state.current_list[state.cursor]
  M.close()
  if selected then
    vim.cmd("edit " .. selected.path)
  end
end

function M.close()
  if state.windows.prompt and vim.api.nvim_win_is_valid(state.windows.prompt) then
    vim.api.nvim_win_close(state.windows.prompt, true)
  end
  if state.windows.result and vim.api.nvim_win_is_valid(state.windows.result) then
    vim.api.nvim_win_close(state.windows.result, true)
  end
  vim.cmd("stopinsert")
end

function M.setup(user_config)
  state.config = vim.tbl_deep_extend("force", defaults, user_config or {})
  if not state.config.enabled then return end

  set_highlights()


  if vim.fn.isdirectory(state.config.localDir) == 0 then
    vim.fn.mkdir(state.config.localDir, "p")
  end

  local km = state.config.keymaps
  vim.keymap.set("n", km.openlocal, function() M.open_picker(true) end, { desc = "Docs: Local Files" })
  vim.keymap.set("n", km.createdoc, M.create_doc, { desc = "Docs: New Document" })
end

function M.create_doc()
  local name = vim.fn.input("Doc Name: ")
  if name == "" then return end
  local path = state.config.localDir .. name .. ".md"
  vim.cmd("edit " .. path)
end

return M
