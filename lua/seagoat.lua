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

  -- Start the SeaGOAT process with -g, --vimgrep and the current working directory.
  local job_id = vim.fn.jobstart({ "seagoat", "-g", "--vimgrep", query, cwd }, {
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
        -- If exit_code isn't zero and we have stderr lines, show them with a blocking message:
        if #stderr_lines > 0 then
          vim.api.nvim_err_writeln(table.concat(stderr_lines, "\n"))
        else
          -- Otherwise just notify that SeaGOAT exited with a non-zero code:
          vim.api.nvim_err_writeln("SeaGOAT exited with code: " .. exit_code)
        end
        return
      end

      -- If we're here, exit_code was 0. Proceed with normal logic:
      if #stdout_lines > 0 then
        vim.fn.setqflist({}, "r", { lines = stdout_lines, title = "SeaGOAT Results" })
        vim.cmd("copen")
      else
        vim.notify("No valid search results from SeaGOAT.", vim.log.levels.INFO)
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
