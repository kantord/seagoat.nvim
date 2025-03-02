local M = {}

-- Function to run SeaGOAT with the provided query.
function M.search(query)
  if not query or query == "" then
    vim.notify("A query argument is required.", vim.log.levels.ERROR)
    return
  end

  local cwd = vim.fn.getcwd()
  local stdout_lines = {}
  local stderr_lines = {}

  -- Start the SeaGOAT process with the -g argument and current working directory.
  local job_id = vim.fn.jobstart({ "seagoat", "-g", query, cwd }, {
    stdout_buffered = true,
    stderr_buffered = true,
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
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stderr_lines, line)
          end
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      if exit_code ~= 0 then
        vim.notify("SeaGOAT exited with code: " .. exit_code, vim.log.levels.ERROR)
      end

      -- Process each line from stdout and parse expected vimgrep output:
      local qf_items = {}
      for _, line in ipairs(stdout_lines) do
        -- Expected format: filename:line:col: message
        local file, lnum, col, text = line:match("([^:]+):(%d+):(%d+):(.*)")
        if file and lnum and col and text then
          table.insert(qf_items, {
            filename = file,
            lnum = tonumber(lnum),
            col = tonumber(col),
            text = text,
          })
        else
          table.insert(qf_items, { text = line })
        end
      end

      vim.fn.setqflist({}, " ", { title = "SeaGOAT Results", items = qf_items })
      vim.cmd("copen")

      if #stderr_lines > 0 then
        vim.notify(table.concat(stderr_lines, "\n"), vim.log.levels.INFO)
      end
    end,
  })

  if job_id <= 0 then
    vim.notify("Failed to start SeaGOAT.", vim.log.levels.ERROR)
  end
end

-- Create a Neovim command ":SeaGOAT" that requires a query argument.
vim.api.nvim_create_user_command("SeaGOAT", function(opts)
  M.search(opts.args)
end, { nargs = 1 })

return M
