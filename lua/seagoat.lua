


local M = {}

-- Helper: Process spinner output from stderr.
local function process_spinner_data(data)
  local spinner_line = ""
  for _, chunk in ipairs(data) do
    chunk = chunk:gsub("\n", "")
    local parts = vim.split(chunk, "\r")
    spinner_line = parts[#parts] or spinner_line
  end
  return spinner_line
end

-- Helper: Update the command line with the spinner text.
local function update_spinner(spinner_text)
  vim.api.nvim_echo({ { spinner_text, "None" } }, false, {})
end

-- Function to run SeaGOAT with the provided query.
function M.search(query)
  if not query or query == "" then
    vim.notify("A query argument is required.", vim.log.levels.ERROR)
    return
  end

  local cwd = vim.fn.getcwd()
  local stdout_lines = {}  -- We'll store each stdout line as it arrives.

  local job_id = vim.fn.jobstart({ "seagoat", "-g", query, cwd }, {
    -- We use unbuffered mode to handle partial updates as they come.
    stdout_buffered = false,
    stderr_buffered = false,

    on_stdout = function(_, data, _)
      -- Each element of `data` typically corresponds to a line (or partial line).
      -- We'll insert non-empty lines into our table for the quickfix list.
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stdout_lines, line)
          end
        end
      end
    end,

    on_stderr = function(_, data, _)
      -- We treat stderr as spinner output; parse & update the spinner in the command line.
      if data then
        local spinner = process_spinner_data(data)
        if spinner and spinner ~= "" then
          update_spinner(spinner)
        end
      end
    end,

    on_exit = function(_, exit_code, _)
      -- If SeaGOAT fails, show an error.
      if exit_code ~= 0 then
        vim.notify("SeaGOAT exited with code: " .. exit_code, vim.log.levels.ERROR)
      end

      -- Convert stdout_lines to a quickfix list.
      local qf_items = {}
      for _, line in ipairs(stdout_lines) do
        table.insert(qf_items, { text = line })
      end

      local title = 'SeaGOAT Results for "' .. query .. '"'
      vim.fn.setqflist({}, " ", { title = title, items = qf_items })
      vim.cmd("copen")

      -- Clear the spinner message.
      vim.api.nvim_echo({ { "" } }, false, {})
    end,
  })

  if job_id <= 0 then
    vim.notify("Failed to start SeaGOAT.", vim.log.levels.ERROR)
  end
end

vim.api.nvim_create_user_command("SeaGOAT", function(opts)
  M.search(opts.args)
end, { nargs = 1 })

return M


