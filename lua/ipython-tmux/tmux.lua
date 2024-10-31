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
        return vim.split(tmux_info, ",", {})[1]
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
---@param exact boolean
---@param cmd string
---@return boolean
M.check_if_python = function(pane, exact, cmd)
    if not exact then
        if pane.cur_cmd:lower():find(cmd) ~= nil then
            return true
        end

        return false
    end

    if pane.cur_cmd:lower() == "python" then
        return true
    end

    return false
end

---Return the number of panes in window
---@return integer
M.get_number_panes = function()
    local cmd_out = M.execute("list-panes")
    return #vim.split(cmd_out, "\n", {})
end

---Get information about all panes in current tmux window
---cmd_out is a string which is specifcally formatted
---The format can be seen under |get_pane|
---@param cmd_out string
---@return { active: string, index: string, pid: string, cur_cmd: string, id: string }[]
M.get_pane_infos = function(cmd_out)
    local pane_infos = {}

    for _, pane_info in pairs(vim.split(cmd_out, "\n", {})) do
        local info_splitted = vim.split(pane_info, " ", {})
        if #info_splitted > 1 then
            local index = tonumber(info_splitted[2])
            local info_table = {
                active = info_splitted[1],
                index = info_splitted[2],
                pid = info_splitted[3],
                cur_cmd = info_splitted[4],
                id = info_splitted[5],
            }

            if index then
                table.insert(pane_infos, index + 1, info_table)
            end
        end
    end
    return pane_infos
end

---Get command of specified pane
---@param pane_num any
---@return string
M.get_pane_cur_command = function(pane_num)
    local cmd = string.format("list-panes -F '#{pane_current_command}' -f '#{m:%s,#{pane_id}}'", pane_num)
    local pane_cur_cmd = vim.split(M.execute(cmd), "\n", {})[1]
    return pane_cur_cmd
end

---Returns the via pane_num specified pane or if only 2 panes are currently there the not active one
---@param pane_num number?
---@return { active: string, index: string, pid: string, cur_cmd: string, id: string } | nil
M.get_pane = function(pane_num)
    if pane_num then
        pane_num = pane_num + 1
    end

    if M.get_tmux() then
        local cmd_out =
            M.execute("list-panes -F '#{pane_active} #{pane_index} #{pane_pid} #{pane_current_command} #{pane_id}'")

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

---Escape ' and " for sending strings to tmux
---@param str string
local encode_for_tmux = function(str)
    return str:gsub('"', [[\%1]])
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
    local cmd = string.format("send-keys -t '%s' '%s' Enter", pane_id, str)
    M.execute(cmd)
end

---Send a string to a tmux pane
---@param pane_id string
---@param str string
M.send_string = function(pane_id, str)
    local cmd = string.format("send-keys -t '%s' '%s'", pane_id, str)
    M.execute(cmd)
end

---Send a string to a tmux pane
---@param pane_id string
---@param str string
M.send_string_literal = function(pane_id, str)
    local cmd = string.format('send-keys -t "%s" %s', pane_id, str)
    M.execute(cmd)
end

---Run the specified python command in the connected tmux pane
---@param pane { active: string, index: string, pid: string, cur_cmd: string, id: string }
---@param python_command any
M.run_python = function(pane, python_command)
    M.send_string_enter(pane.id, python_command)
end

---Send lines of text to a pane
---@param pane_id string
---@param cell_text string[]
M.send_text_to_pane = function(pane_id, cell_text)
    local cell_text_concat = table.concat(
        vim.tbl_map(function(s)
            return '"' .. encode_for_tmux(s) .. '"'
        end, cell_text),
        " C-q C-j "
    )
    M.send_string(pane_id, "C-a")
    M.send_string_literal(pane_id, cell_text_concat)
    M.send_enter(pane_id)

    local tab_char
    if vim.bo.expandtab == false then
        tab_char = "\t"
        if cell_text[#cell_text]:sub(1, 1) == tab_char then
            M.send_enter(pane_id)
        end
    else
        tab_char = string.rep(" ", vim.bo.tabstop)
        if cell_text[#cell_text]:sub(1, vim.bo.tabstop) == tab_char then
            M.send_enter(pane_id)
        end
    end
end

return M
