local tmux = require("ipython-paste.tmux")
local text = require("ipython-paste.text")

local M = {}

M.config = {
    python_command = "ipython --no-banner",
    cell_comment = "# %%",
    python_tmux_cmd = "python"
}

M.pane = nil

---Setup the ipython-paste plugin
---Defaults are:
---{
---    python_command = "ipython --no-banner",
---    cell_comment = "# %%"
---}
---@param opts { python_command: string, cell_comment: string }
M.setup = function(opts)
    if opts and #opts > 0 then
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
            local array_options = vim.fn.range(count_pane-1)
            local array_options_cast = vim.fn.map(array_options, function(_, v) return tostring(v) end)
            return array_options_cast
        end
    })

    vim.api.nvim_create_user_command("IPythonDisconnect", function(_)
        M.disconnect()
    end, {})

    vim.api.nvim_create_user_command("IPythonSendCell", function(_)
        M.send_cell()
    end, {})
end

---Connect to tmux pane
---@param pane_num number?
M.connect = function(pane_num)
    if not M.pane then
        local pane = tmux.get_pane(pane_num)
        if pane and not tmux.check_if_python(pane) then
            tmux.run_python(pane, M.config.python_command)
            pane.cur_cmd = M.config.python_tmux_cmd
        end
        M.pane = pane
    else
        vim.api.nvim_err_writeln(string.format("Please only connect with one pane. You are currenty connected to pane '%s'. First use the disconnect function to change pane."
            , M.pane.index))
    end
end

---Disconnect from tmux pane
M.disconnect = function()
    M.pane = nil
end

---Send a ipython cell to connected tmux pane
M.send_cell = function()
    if not M.pane then
        vim.api.nvim_err_writeln("Please call connect first.")
        return
    end

    if not tmux.check_if_python(M.pane) then
        vim.api.nvim_err_writeln("Please start python in your connected pane (normally it should happen on connection). Calling disconnect...")
        M.disconnect()
        return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local lines = text.find_cell_block(bufnr, M.config.cell_comment)

    if not lines then
        return
    end

    if not lines.next_cmt_ln then
        lines.next_cmt_ln = -1
    end

    local cell_text = text.get_cell_text(bufnr, lines.prev_cmt_ln + 1, lines.next_cmt_ln)

    for i, line_text in ipairs(cell_text) do
        tmux.send_string(M.pane.id, "C-a")
        tmux.send_string(M.pane.id, line_text)
        if i ~= #cell_text then
            tmux.send_string(M.pane.id, "C-o")
            tmux.send_string(M.pane.id, "DOWN")
        end
    end

    tmux.send_enter(M.pane.id)
end

return M
