local M = {}

---Returns the current tmux info
---@return string?
M.get_tmux = function()
    return os.getenv("TMUX")
end


---Get id of active tmux pane
---@return string?
M.get_active_pane_id = function()
    return os.getenv("TMUX_PANE")
end

---This returns the socket of the current tmux session
---@return string?
M.get_socket = function()
    local tmux_info = M.get_tmux()
    if tmux_info then
        return vim.split(tmux_info, ",")[1]
    end
end

---This executes a tmux command. "pre" lets you and something before the tmux call
---@param arg string
---@param pre string?
---@return string
M.execute = function(arg, pre)
    local command = string.format("%s tmux -S %s %s", pre or "", M.get_socket(), arg)

    local handle = assert(io.popen(command), string.format("unable to execute: [%s]", command))
    local result = handle:read("*a")
    handle:close()

    return result
end

---Check if python is running in a pane
---@param pane { active: string, index: string, pid: string, cur_cmd: string, id: string }
---@return boolean
M.check_if_python = function(pane)
    if pane.cur_cmd == "python" then
        return true
    else
        return false
    end
end

---Get information about all panes in current tmux window
---cmd_out is a string which is specifcally formatted
---The format can be seen under |get_pane|
---
---@param cmd_out string
---@return { active: string, index: string, pid: string, cur_cmd: string, id: string }[]
M.get_pane_infos = function(cmd_out)
    local pane_infos = {}

    for _, pane_info in pairs(vim.split(cmd_out, "\n")) do
        local info_splitted = vim.split(pane_info, " ")
        if #info_splitted > 1 then
            local index = tonumber(info_splitted[2])
            local info_table = {
                active = info_splitted[1],
                index = info_splitted[2],
                pid = info_splitted[3],
                cur_cmd = info_splitted[4],
                id = info_splitted[5]
            }

            if index then
                table.insert(pane_infos, index + 1, info_table)
            end
        end
    end
    return pane_infos
end

---Returns the via pane_num specified pane or if only 2 panes are currently there the not active one
---@param pane_num number?
---@return { active: string, index: string, pid: string, cur_cmd: string, id: string } | nil
M.get_pane = function(pane_num)
    if pane_num then
        pane_num = pane_num + 1
    end

    if M.get_tmux() then
        local cmd_out = M.execute("list-panes -F '#{pane_active} #{pane_index} #{pane_pid} #{pane_current_command} #{pane_id}'")

        local pane_candidate = nil

        local pane_infos = M.get_pane_infos(cmd_out)

        if #pane_infos == 2 then
            for _, pane_info in pairs(pane_infos) do
                if pane_info.active == "0" then
                    pane_candidate = pane_info
                end
            end
        else
            if pane_num == nil then
                vim.api.nvim_err_writeln("Please specify the tmux pane number (to check use tmux-prefix + q)")
                return nil
            end
            if pane_infos[pane_num].active ~= 1 then
                pane_candidate = pane_infos[pane_num]
            else
                vim.api.nvim_err_writeln("pane num cannot be the active pane as this is the nvim pane")
                return nil
            end
        end

        if pane_candidate then
            return pane_candidate
        end
        return nil
    end
end


---Send a enter command to a tmux pane
---@param pane_id string
M.send_enter = function(pane_id)
    local cmd = string.format("send-keys -t '%s' Enter", pane_id)
    M.execute(cmd)
end

---Send a string to a tmux pane and press enter to for example execute
---@param pane_id string
---@param str string
M.send_string_enter = function(pane_id, str)
    local cmd = str.format("send-keys -t '%s' '%s' Enter", pane_id, str)
    M.execute(cmd)
end

---Send a string to a tmux pane
---@param pane_id string
---@param str string
M.send_string = function(pane_id, str)
    local cmd = string.format("send-keys -t '%s' '%s'", pane_id, str)
    M.execute(cmd)
end

---
---@param pane { active: string, index: string, pid: string, cur_cmd: string, id: string }
---@param python_command any
M.run_python = function(pane, python_command)
    M.send_string_enter(pane.id, python_command)
end

return M
