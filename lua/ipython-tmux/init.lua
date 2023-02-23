local tmux = require("ipython-tmux.tmux")
local text = require("ipython-tmux.text")

local M = {}

M.config = {
    python_command = "ipython --no-banner",
    cell_comment = "# %%",
    python_tmux_cmd = "python",
    python_tmux_cmd_exact = false,
    exit_on_disconnect = true,
    exit_on_disconnect_cmd = "exit()",
}

M.pane = nil

---Setup the ipython-tmux plugin
---Defaults are:
---{
---    python_command = "ipython --no-banner",
---    cell_comment = "# %%"
---}
---@param opts { python_command: string, cell_comment: string }
M.setup = function(opts)
    if opts and next(opts) ~= nil then
        M.config = opts
    end

    vim.api.nvim_create_user_command("IPythonConnect", function(args)
        if #args.fargs > 0 then
            M.connect(tonumber(args.args))
            return
        end
        M.connect()
    end, {
        nargs = '?',
        complete = function(_, _, _)
            local count_pane = tmux.get_number_panes()
            local array_options = vim.fn.range(count_pane - 1)
            local array_options_cast = vim.fn.map(array_options, function(_, v) return tostring(v) end)
            return array_options_cast
        end
    })

    vim.api.nvim_create_user_command("IPythonDisconnect", function(_)
        M.disconnect()
    end, {})

    vim.api.nvim_create_user_command("IPythonSendCell", function(_)
        M.send_text()
    end, {})
end

---Connect to tmux pane
---@param pane_num number?
M.connect = function(pane_num)
    if not M.pane then
        local pane = tmux.get_pane(pane_num)
        if pane and not tmux.check_if_python(pane, M.config.python_tmux_cmd_exact, M.config.python_tmux_cmd) then
            tmux.run_python(pane, M.config.python_command)
            pane.cur_cmd = M.config.python_tmux_cmd
        end
        M.pane = pane
    else
        vim.api.nvim_err_writeln(string.format(
            "Please only connect with one pane. You are currenty connected to pane '%s'. First use the disconnect function to change pane."
            , M.pane.index))
    end
end

---Disconnect from tmux pane
M.disconnect = function()
    M.pane.cur_cmd = tmux.get_pane_cur_command(M.pane.id)
    if M.pane and tmux.check_if_python(M.pane, M.config.python_tmux_cmd_exact, M.config.python_tmux_cmd) and M.config.exit_on_disconnect then
        tmux.send_string_enter(M.pane.id, M.config.exit_on_disconnect_cmd)
    end
    M.pane = nil
end

---Send an ipython cell or visual selected text to connected tmux pane
M.send_cell = function()
    if not M.pane then
        vim.api.nvim_err_writeln("Please call connect first.")
        return
    end

    M.pane.cur_cmd = tmux.get_pane_cur_command(M.pane.id)

    if not tmux.check_if_python(M.pane, M.config.python_tmux_cmd_exact, M.config.python_tmux_cmd) then
        vim.api.nvim_err_writeln(
            "Please start python in your connected pane (normally it should happen on connection). Calling disconnect...")
        M.disconnect()
        return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local lines = text.get_cell_lns(bufnr, M.config.cell_comment)

    if not lines then
        vim.api.nvim_err_writeln("Lines not found.")
        return
    end

    if not lines.last_ln then
        lines.last_ln = -1
    end

    local cell_text = text.get_lns_text(bufnr, lines.first_ln + 1, lines.last_ln)

    tmux.send_text_to_pane(M.pane.id, cell_text)
end

return M
