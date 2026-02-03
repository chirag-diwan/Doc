local M = {}


local Config = {
  enabled = true,
  icons = {
    search = "🔍",
    file = "📄",
    dir = "📁",
    net = "🌐",
    spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
  },
  keymaps = {
    openauto = "<leader>da",
    open = "<leader>do",
    openlocal = "<leader>dl",
    createdoc = "<leader>dc",
  },
  local_dir = vim.fn.stdpath("data") .. "/docs/",

  default_topics = {
    "lua", "python", "javascript", "typescript", "rust", "go", "c++", "c",
    "html", "css", "docker", "kubernetes", "git", "bash", "vim", "react",
    "sql", "regex", "markdown", "json", "yaml"
  },
}

local State = {
  buf = { prompt = nil, results = nil },
  win = { prompt = nil, results = nil },
  ns = vim.api.nvim_create_namespace("doc_plugin_ui"),
  mode = "local",
  query = "",
  cursor = 1,
  results = {},
  spinner_timer = nil,
  spinner_frame = 1,
  loading = false,
  files_cache = {},
}




local Utils = {}

function Utils.debounce(ms, fn)
  local timer = vim.uv.new_timer()
  return function(...)
    local args = { ... }
    timer:stop()
    timer:start(ms, 0, vim.schedule_wrap(function()
      fn(unpack(args))
    end))
  end
end

function Utils.center_win_opts(width_pct, height_pct)
  local cols = vim.o.columns
  local lines = vim.o.lines
  local width = math.floor(cols * width_pct)
  local height = math.floor(lines * height_pct)
  local row = math.floor((lines - height) / 2)
  local col = math.floor((cols - width) / 2)
  return { width = width, height = height, row = row, col = col }
end

function Utils.fs_scan(path)
  local files = {}
  local handle = vim.uv.fs_scandir(path)
  if not handle then return files end

  while true do
    local name, type = vim.uv.fs_scandir_next(handle)
    if not name then break end
    local full_path = path .. "/" .. name
    if type == "directory" then
      local sub = Utils.fs_scan(full_path)
      vim.list_extend(files, sub)
    else
      table.insert(files, { name = name, path = full_path, type = "file" })
    end
  end
  return files
end

local UI = {}

function UI.setup_highlights()
  local hls = {
    DocBorder    = { link = "FloatBorder", default = true },
    DocTitle     = { link = "FloatTitle", default = true },
    DocSelection = { link = "Visual", default = true },
    DocIcon      = { link = "Directory", default = true },
    DocFile      = { link = "String", default = true },
    DocPrompt    = { link = "Normal", default = true },
    DocSpinner   = { link = "WarningMsg", default = true },
  }
  for group, opts in pairs(hls) do
    vim.api.nvim_set_hl(0, group, opts)
  end
end

function UI.start_spinner()
  if State.spinner_timer then return end
  State.loading = true
  State.spinner_timer = vim.uv.new_timer()
  State.spinner_timer:start(0, 100, vim.schedule_wrap(function()
    State.spinner_frame = (State.spinner_frame % #Config.icons.spinner) + 1
    UI.render_prompt_title()
  end))
end

function UI.stop_spinner()
  if State.spinner_timer then
    State.spinner_timer:stop()
    State.spinner_timer:close()
    State.spinner_timer = nil
  end
  State.loading = false
  UI.render_prompt_title()
end

function UI.render_prompt_title()
  if not State.win.prompt or not vim.api.nvim_win_is_valid(State.win.prompt) then return end

  local icon = State.loading
      and Config.icons.spinner[State.spinner_frame]
      or Config.icons.search

  local title_text = string.format(" %s %s Docs ", icon, (State.mode == "local" and "Local" or "Online"))


  vim.api.nvim_win_set_config(State.win.prompt, {
    title = title_text,
    title_pos = "center"
  })
end

function UI.render_results()
  if not State.buf.results or not vim.api.nvim_buf_is_valid(State.buf.results) then return end

  local lines = {}
  local highlights = {}

  if #State.results == 0 then
    lines = { "", "   No results found for '" .. State.query .. "'" }
  else
    for i, item in ipairs(State.results) do
      local icon = State.mode == "local" and Config.icons.file or Config.icons.net
      local name = type(item) == "string" and item or item.name
      local padding = (i == State.cursor) and " > " or "   "
      table.insert(lines, string.format("%s%s %s", padding, icon, name))


      table.insert(highlights, {
        line = i - 1,
        is_selected = (i == State.cursor)
      })
    end
  end

  vim.api.nvim_buf_set_lines(State.buf.results, 0, -1, false, lines)


  vim.api.nvim_buf_clear_namespace(State.buf.results, State.ns, 0, -1)

  for _, hl in ipairs(highlights) do
    if hl.is_selected then
      vim.api.nvim_buf_add_highlight(State.buf.results, State.ns, "DocSelection", hl.line, 0, -1)
    end

    vim.api.nvim_buf_add_highlight(State.buf.results, State.ns, "DocIcon", hl.line, 3, 6)

    vim.api.nvim_buf_add_highlight(State.buf.results, State.ns, "DocFile", hl.line, 6, -1)
  end
end

local Core = {}

function Core.filter_list()
  local q = State.query:lower()

  local source = {}
  if State.mode == "local" then
    source = State.files_cache
  else
    source = Config.default_topics
  end

  if q == "" then
    State.results = source
  else
    State.results = vim.tbl_filter(function(item)
      local text = (type(item) == "table" and item.name or item):lower()
      return text:find(q, 1, true) ~= nil
    end, source)
  end


  if State.mode == "online" and q ~= "" then
    local exact_match = false
    for _, item in ipairs(State.results) do
      if item == q then
        exact_match = true
        break
      end
    end
    if not exact_match then
      table.insert(State.results, 1, q)
    end
  end

  State.cursor = 1
  UI.render_results()
end

Core.on_input = Utils.debounce(50, function()
  if not State.buf.prompt or not vim.api.nvim_buf_is_valid(State.buf.prompt) then return end
  local lines = vim.api.nvim_buf_get_lines(State.buf.prompt, 0, 1, false)
  local new_query = lines[1] or ""

  if new_query ~= State.query then
    State.query = new_query
    Core.filter_list()
  end
end)

function Core.confirm()
  local selection = State.results[State.cursor]
  if not selection then return end

  M.close()

  if State.mode == "local" then
    Core.open_floating_doc(selection.path, selection.name)
  else
    Core.fetch_online(selection)
  end
end

function Core.fetch_online(query)
  local url = string.format("https://cheat.sh/%s?T", query)


  local buf = vim.api.nvim_create_buf(false, true)
  local dim = Utils.center_win_opts(0.8, 0.8)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = dim.width,
    height = dim.height,
    row = dim.row,
    col = dim.col,
    style = "minimal",
    border = "rounded",
    title = " Fetching " .. query .. "... ",
  })


  vim.system({ "curl", "-s", url }, { text = true }, vim.schedule_wrap(function(obj)
    if not vim.api.nvim_win_is_valid(win) then return end

    if obj.code ~= 0 then
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Error fetching data.", obj.stderr })
      return
    end

    local lines = vim.split(obj.stdout, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value("filetype", "sh", { buf = buf })
    vim.api.nvim_win_set_config(win, { title = " " .. query .. " " })


    vim.keymap.set("n", "q", function() vim.api.nvim_win_close(win, true) end, { buffer = buf })
  end))
end

function Core.open_floating_doc(path, title)
  local dim = Utils.center_win_opts(0.8, 0.8)
  local buf = vim.api.nvim_create_buf(false, true)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = dim.width,
    height = dim.height,
    row = dim.row,
    col = dim.col,
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
  })

  vim.cmd("edit " .. vim.fn.fnameescape(path))
  vim.keymap.set("n", "q", ":close<CR>", { buffer = buf, silent = true })
  vim.wo[win].winhl = "Normal:NormalFloat,FloatBorder:DocBorder"
end

function M.open_picker(mode)
  State.mode = mode
  State.query = ""
  State.cursor = 1


  if mode == "local" then
    if vim.fn.isdirectory(Config.local_dir) == 0 then
      vim.fn.mkdir(Config.local_dir, "p")
    end
    State.files_cache = Utils.fs_scan(Config.local_dir)
  end


  local total_width = math.floor(vim.o.columns * 0.6)
  local total_height = 15
  local row_start = math.floor((vim.o.lines - total_height) / 2)
  local col_start = math.floor((vim.o.columns - total_width) / 2)


  State.buf.results = vim.api.nvim_create_buf(false, true)
  State.win.results = vim.api.nvim_open_win(State.buf.results, false, {
    relative = "editor",
    width = total_width,
    height = total_height - 3,
    row = row_start + 3,
    col = col_start,
    style = "minimal",
    border = "rounded",
  })


  State.buf.prompt = vim.api.nvim_create_buf(false, true)
  State.win.prompt = vim.api.nvim_open_win(State.buf.prompt, true, {
    relative = "editor",
    width = total_width,
    height = 1,
    row = row_start,
    col = col_start,
    style = "minimal",
    border = "rounded",
    title = " Search ",
    title_pos = "center"
  })


  vim.wo[State.win.results].winhl = "Normal:NormalFloat,FloatBorder:DocBorder"
  vim.wo[State.win.prompt].winhl = "Normal:DocPrompt,FloatBorder:DocBorder"
  vim.api.nvim_set_option_value("buftype", "prompt", { buf = State.buf.prompt })


  local opts = { buffer = State.buf.prompt, silent = true }

  vim.keymap.set("i", "<C-n>", function()
    State.cursor = math.min(#State.results, State.cursor + 1)
    UI.render_results()
  end, opts)

  vim.keymap.set("i", "<C-p>", function()
    State.cursor = math.max(1, State.cursor - 1)
    UI.render_results()
  end, opts)

  vim.keymap.set("i", "<CR>", Core.confirm, opts)
  vim.keymap.set({ "i", "n" }, "<Esc>", M.close, opts)


  vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = State.buf.prompt,
    callback = Core.on_input
  })


  UI.render_prompt_title()
  Core.filter_list()
  vim.cmd("startinsert")
end

function M.create_doc()
  local name = vim.fn.input("New Doc Name: ")
  if name == "" then return end

  if not name:match("%.md$") then name = name .. ".md" end

  if vim.fn.isdirectory(Config.local_dir) == 0 then
    vim.fn.mkdir(Config.local_dir, "p")
  end

  local path = Config.local_dir .. name
  Core.open_floating_doc(path, name)
end

function M.close()
  if State.win.prompt and vim.api.nvim_win_is_valid(State.win.prompt) then
    vim.api.nvim_win_close(State.win.prompt, true)
  end
  if State.win.results and vim.api.nvim_win_is_valid(State.win.results) then
    vim.api.nvim_win_close(State.win.results, true)
  end
  State.win.prompt = nil
  State.win.results = nil
  UI.stop_spinner()
  vim.cmd("stopinsert")
end

function M.setup(user_opts)
  Config = vim.tbl_deep_extend("force", Config, user_opts or {})
  if not Config.enabled then return end

  UI.setup_highlights()


  local km = Config.keymaps
  vim.keymap.set("n", km.openlocal, function() M.open_picker("local") end, { desc = "Docs: Local" })
  vim.keymap.set("n", km.open, function() M.open_picker("online") end, { desc = "Docs: Online" })
  vim.keymap.set("n", km.createdoc, M.create_doc, { desc = "Docs: Create New" })
end

return M
