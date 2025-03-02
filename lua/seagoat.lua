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

  -- We'll collect stdout lines in-memory, then write them to a temp file after the job ends.
  local stdout_lines = {}

  local job_id = vim.fn.jobstart({ "seagoat", "-g", query, "--vimgrep", cwd }, {
    stdout_buffered = false, -- read chunks as they arrive
    stderr_buffered = false,

    on_stdout = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stdout_lines, line)
          end
        end
      end
    end,

    on_stderr = function(_, data, _)
      -- We treat stderr as spinner output.
      if data then
        local spinner = process_spinner_data(data)
        if spinner and spinner ~= "" then
          update_spinner(spinner)
        end
      end
    end,

    on_exit = function(_, exit_code, _)
      if exit_code ~= 0 then
        vim.notify("SeaGOAT exited with code: " .. exit_code, vim.log.levels.ERROR)
      end

      -- Write all captured lines to a temporary file.
      local temp_file = vim.fn.tempname()
      local f = io.open(temp_file, "w")
      f:write(table.concat(stdout_lines, "\n") .. "\n")
      f:close()

      -- Now ask Neovim to parse that file as a vimgrep result list.
      vim.cmd("cfile " .. temp_file)
      vim.cmd("copen")

      -- Clear the spinner message from the command line.
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
