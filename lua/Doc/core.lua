local M = {}


local defaults = {
  enabled = true,
  keymaps = {
    openauto = "<leader>da",
    open = "<leader>do",
    openlocal = "<leader>dl",
    createdoc = "<leader>dc"
  },
  localDir = vim.fn.stdpath("data") .. "/tmp/doc/",

  ui = {
    icons = {
      search = " ",
      file = "📄",
      dir = " ",
      pill = "│",
    },
    winblend = 10,
    border = "solid",
  }
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


local has_devicons, devicons = pcall(require, "nvim-web-devicons")

local function get_icon(name, is_dir)
  if is_dir then return defaults.ui.icons.dir, "DocsDir" end
  if not has_devicons then return defaults.ui.icons.file, "DocsFile" end

  local ext = vim.fn.fnamemodify(name, ":e")
  local icon, icon_name = devicons.get_icon(name, ext, { default = true })
  return icon .. " ", "DevIcon" .. icon_name
end

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
  local hls = {
    DocsBorder     = { fg = "#89b4fa" },
    DocsTitle      = { fg = "#cba6f7", bold = true },
    DocsPrompt     = { fg = "#cdd6f4" },
    DocsPromptIcon = { fg = "#f9e2af" },
    DocsSel        = { bg = "#313244", bold = true },
    DocsSelIcon    = { fg = "#a6e3a1" },
    DocsMatch      = { fg = "#f38ba8", bold = true, underline = true },
    DocsComment    = { fg = "#6c7086", italic = true },
    DocsDir        = { fg = "#89b4fa" },
    DocsFile       = { fg = "#a6adc8" },
  }

  for name, opts in pairs(hls) do
    opts.default = true
    vim.api.nvim_set_hl(0, name, opts)
  end
end

function M.render_results()
  if not state.buffers.result or not vim.api.nvim_buf_is_valid(state.buffers.result) then return end


  vim.api.nvim_buf_clear_namespace(state.buffers.result, state.ns, 0, -1)


  if #state.current_list == 0 then
    local empty_msg = "   󰅺  No results found"
    vim.api.nvim_buf_set_lines(state.buffers.result, 0, -1, false, { "", empty_msg })
    vim.api.nvim_buf_add_highlight(state.buffers.result, state.ns, "DocsComment", 1, 0, -1)
    return
  end

  if not state.is_local then
    local lines = {}

    for _, item in ipairs(state.current_list) do
      table.insert(lines, "  " .. item)
    end
    vim.api.nvim_buf_set_lines(state.buffers.result, 0, -1, false, lines)

    local idx = state.cursor - 1


    if state.current_list[state.cursor] then
      vim.api.nvim_buf_add_highlight(state.buffers.result, state.ns, "DocsSel", idx, 0, -1)
      vim.api.nvim_buf_set_extmark(state.buffers.result, state.ns, idx, 0, {
        virt_text = { { defaults.ui.icons.pill, "DocsTitle" } },
        virt_text_pos = "overlay",
      })
    end


    if state.prompt ~= "" then
      for i, item in ipairs(state.current_list) do
        local start_match, end_match = item:lower():find(state.prompt:lower(), 1, true)
        if start_match then
          vim.api.nvim_buf_add_highlight(state.buffers.result, state.ns, "DocsMatch", i - 1, start_match + 1,
            end_match + 2)
        end
      end
    end

    return
  end


  local lines = {}
  local icon_data = {}


  for i, entry in ipairs(state.current_list) do
    local name = (type(entry) == "table") and entry.name or entry
    local is_dir = (type(entry) == "table") and (entry.type == "directory") or false


    local icon, icon_hl = get_icon(name, is_dir)


    local display_line = string.format("  %s %s", icon, name)
    table.insert(lines, display_line)

    table.insert(icon_data, {
      icon_len = #icon,
      icon_hl = icon_hl,
      text_start = 4 + #icon
    })
  end

  vim.api.nvim_buf_set_lines(state.buffers.result, 0, -1, false, lines)


  for i, entry in ipairs(state.current_list) do
    local idx = i - 1
    local name = (type(entry) == "table") and entry.name or entry
    local meta = icon_data[i]


    if i == state.cursor then
      vim.api.nvim_buf_add_highlight(state.buffers.result, state.ns, "DocsSel", idx, 0, -1)

      vim.api.nvim_buf_set_extmark(state.buffers.result, state.ns, idx, 0, {
        virt_text = { { defaults.ui.icons.pill, "DocsTitle" } },
        virt_text_pos = "overlay",
      })
    end


    vim.api.nvim_buf_add_highlight(state.buffers.result, state.ns, meta.icon_hl, idx, 2, 2 + meta.icon_len)


    if state.prompt ~= "" then
      local start_match, end_match = name:lower():find(state.prompt:lower(), 1, true)
      if start_match then
        local offset = 3 + meta.icon_len
        vim.api.nvim_buf_add_highlight(state.buffers.result, state.ns, "DocsMatch", idx, offset + start_match - 1,
          offset + end_match)
      end
    end


    if type(entry) == "table" and entry.type then
      vim.api.nvim_buf_set_extmark(state.buffers.result, state.ns, idx, 0, {
        virt_text = { { entry.type, "DocsComment" } },
        virt_text_pos = "right_align",
      })
    end
  end
end

function M.filter_list()
  if state.is_local then
    local all = scan_local_dir(state.config.localDir)

    if state.prompt == "" then
      state.current_list = all
    else
      state.current_list = vim.tbl_filter(function(item)
        return item.name:lower():find(state.prompt:lower(), 1, true) ~= nil
      end, all)
    end

    state.cursor = math.min(math.max(1, state.cursor), #state.current_list)
  else
    if state.prompt == "" then
      state.current_list = state.indices.entries
    else
      state.current_list = vim.tbl_filter(function(item)
        return item:lower():find(state.prompt:lower(), 1, true) ~= nil
      end, state.indices.entries)
    end
  end

  M.render_results()


  if state.is_local and state.windows.result and vim.api.nvim_win_is_valid(state.windows.result) then
    pcall(vim.api.nvim_win_set_cursor, state.windows.result, { state.cursor, 0 })
  end
end

function M.open_picker(is_local)
  state.is_local = is_local
  state.prompt = ""
  state.cursor = 1

  -- Create buffers
  state.buffers.result = vim.api.nvim_create_buf(false, true)
  state.buffers.prompt = vim.api.nvim_create_buf(false, true)

  -- FIX: set bufhidden to wipe so they don't complain about unsaved changes on close
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = state.buffers.result })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = state.buffers.prompt })

  local width = math.floor(vim.o.columns * 0.6)
  local height = 16
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  state.windows.result = vim.api.nvim_open_win(state.buffers.result, false, {
    relative = "editor",
    width = width,
    height = height - 3,
    row = row + 3,
    col = col,
    style = "minimal",
    border = state.config.ui.border,
    title = is_local and "   Local Docs " or " 󰖟 Online Docs ",
    title_pos = "center",
  })

  state.windows.prompt = vim.api.nvim_open_win(state.buffers.prompt, true, {
    relative = "editor",
    width = width,
    height = 1,
    row = row,
    col = col,
    style = "minimal",
    border = state.config.ui.border,
    title = " " .. state.config.ui.icons.search .. " Search ",
    title_pos = "left",
  })

  vim.wo[state.windows.result].cursorline = false
  vim.wo[state.windows.result].winblend = state.config.ui.winblend
  vim.wo[state.windows.result].winhl = "Normal:NormalFloat,FloatBorder:DocsBorder,FloatTitle:DocsTitle"

  vim.wo[state.windows.prompt].winblend = state.config.ui.winblend
  vim.wo[state.windows.prompt].winhl = "Normal:NormalFloat,FloatBorder:DocsBorder,FloatTitle:DocsTitle"

  vim.api.nvim_set_option_value("buftype", "prompt", { buf = state.buffers.prompt })
  vim.fn.prompt_setprompt(state.buffers.prompt, "  ")

  local opts = { buffer = state.buffers.prompt, silent = true }

  vim.keymap.set("i", "<C-n>", function() M.move_cursor(1) end, opts)
  vim.keymap.set("i", "<C-p>", function() M.move_cursor(-1) end, opts)
  vim.keymap.set("i", "<Down>", function() M.move_cursor(1) end, opts)
  vim.keymap.set("i", "<Up>", function() M.move_cursor(-1) end, opts)
  vim.keymap.set("i", "<CR>", M.confirm_selection, opts)
  vim.keymap.set({ "i", "n" }, "<Esc>", M.close, opts)

  M.filter_list()

  vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = state.buffers.prompt,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(state.buffers.prompt, 0, 1, false)
      state.prompt = lines[1] or ""
      if state.prompt:sub(1, 2) == "  " then state.prompt = state.prompt:sub(3) end
      M.filter_list()
    end,
  })

  M.filter_list()
  vim.cmd("startinsert")
end

function M.move_cursor(delta)
  if state.is_local then
    state.cursor = math.max(1, math.min(state.cursor + delta, #state.current_list))

    M.render_results()


    if vim.api.nvim_win_is_valid(state.windows.result) then
      pcall(vim.api.nvim_win_set_cursor, state.windows.result, { state.cursor, 0 })
    end
  else
    state.cursor = math.max(1, math.min(state.cursor + delta, #state.current_list))
    M.render_results()


    if vim.api.nvim_win_is_valid(state.windows.result) then
      pcall(vim.api.nvim_win_set_cursor, state.windows.result, { state.cursor, 0 })
    end
  end
end

function M.confirm_selection()
  if state.is_local then
    local selected = state.current_list[state.cursor]
    -- Close picker BEFORE opening the file to prevent overlapping window issues
    M.close()
    if selected then
      -- Schedule the opening to ensure clean UI state
      vim.schedule(function()
        M.open_floating_file(selected.path)
      end)
    end
  else
    M.close()

    local buf = vim.api.nvim_create_buf(true, false)
    -- FIX: Ensure this temporary result buffer wipes on close
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)

    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      style = "minimal",
      border = "rounded",
      title = " 󰚩 " .. state.prompt .. " ",
      title_pos = "center",
      footer = " q: Close ",
      footer_pos = "center"
    })

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "", "   󰑮  Fetching cheatsheet for '" .. state.prompt .. "'..." })
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })

    local url = string.format("https://cheat.sh/%s?T", state.current_list[state.cursor])

    vim.system({ 'curl', '-s', url }, { text = true }, vim.schedule_wrap(function(obj)
      if not vim.api.nvim_win_is_valid(win) then return end

      if obj.code ~= 0 then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Error fetching data.", obj.stderr })
        return
      end

      local lines = vim.split(obj.stdout, "\n")
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.api.nvim_set_option_value("filetype", "sh", { buf = buf })
      -- Reset modifiable to false so the user doesn't accidentally edit the curl result
      vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
      vim.wo[win].winhl = "Normal:NormalFloat,FloatBorder:DocsBorder,FloatTitle:DocsTitle"
    end))

    vim.keymap.set("n", "q", function() vim.api.nvim_win_close(win, true) end, { buffer = buf, silent = true })
  end
end

function M.close()
  if state.windows.prompt and vim.api.nvim_win_is_valid(state.windows.prompt) then
    vim.api.nvim_win_close(state.windows.prompt, true)
  end

  if state.windows.result and vim.api.nvim_win_is_valid(state.windows.result) then
    vim.api.nvim_win_close(state.windows.result, true)
  end

  -- Clear state references
  state.windows.prompt = nil
  state.windows.result = nil
  state.buffers.prompt = nil
  state.buffers.result = nil

  vim.cmd("stopinsert")
end

function M.setup(user_config)
  state.config = vim.tbl_deep_extend("force", defaults, user_config or {})

  if not state.config.enabled then return end

  set_highlights()

  if vim.fn.isdirectory(state.config.localDir) == 0 then
    vim.fn.mkdir(state.config.localDir, "p")
  end

  state.data_dir = vim.fn.stdpath('data')

  local current_file = debug.getinfo(1, "S").source:sub(2)

  state.data_dir = vim.fn.fnamemodify(current_file, ":h")

  local f = io.open(state.data_dir .. "/index.txt", "r")

  if f then
    for line in f:lines() do
      table.insert(state.indices.entries, line)
    end

    local suc
    suc = f:close()

    if not suc then
      error(err)
    end
  end

  local km = state.config.keymaps

  vim.keymap.set("n", km.openlocal,
    function()
      M.open_picker(true)
    end
    , { desc = "Docs: Local Files" }
  )

  vim.keymap.set("n", km.open, function() M.open_picker(false) end, { desc = "Docs: Online Search" })

  vim.keymap.set("n", km.createdoc, M.create_doc, { desc = "Docs: New Document" })
end

function M.create_doc()
  local name = vim.fn.input("Doc Name: ")

  if name == "" then return end

  local path = state.config.localDir .. name .. ".md"

  M.open_floating_file(path)
end

function M.open_floating_file(path)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = state.config.ui.border,
    title = "  " .. vim.fn.fnamemodify(path, ":t") .. " ",
    title_pos = "center",
  })

  vim.cmd("edit " .. path)
  vim.wo[win].winhl = "Normal:NormalFloat,FloatBorder:DocsBorder,FloatTitle:DocsTitle"
  vim.keymap.set("n", "q", ":close<CR>", { buffer = 0, silent = true, nowait = true })
end

M.setup({})

return M
