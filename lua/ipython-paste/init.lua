local tmux = require("ipython-paste.tmux")
local text = require("ipython-paste.text")

local M = {}

M.config = {
    python_command = "ipython --no-banner",
    cell_comment = "# %%"
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
    M.config = opts
end

---Connect to tmux pane
---@param pane_num number?
M.connect = function(pane_num)
    if not M.pane then
        local pane = tmux.get_pane(pane_num)
        if pane and not tmux.check_if_python(pane) then
            tmux.run_python(pane, M.config.python_command)
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

    tmux.send_string(M.pane.id, "test")
    text.find_previous_comment()
end

M.connect()

return M
