local M = {}

local function get_tmux()
    return os.getenv("TMUX")
end

local function get_tmux_pane()
    return os.getenv("TMUX_PANE")
end

local function get_socket()
    return vim.split(get_tmux(), ",")[1]
end

local function execute(arg, pre)
    local command = string.format("%s tmux -S %s %s", pre or "", get_socket(), arg)

    local handle = assert(io.popen(command), string.format("unable to execute: [%s]", command))
    local result = handle:read("*a")
    handle:close()

    return result
end

local function check_if_python(pane_candidate)
    if pane_candidate.cur_cmd == "python" then
        return true
    else
        return false
    end
end

local function get_pane_infos(cmd_out)
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

local function connect_to_tmux(pane_num)
    pane_num = pane_num + 1

    if get_tmux() then
        local cmd_out = execute("list-panes -F '#{pane_active} #{pane_index} #{pane_pid} #{pane_current_command} #{pane_id}'"
            , nil)

        local pane_candidate = nil

        local pane_infos = get_pane_infos(cmd_out)

        if #pane_infos == 2 then
            for _, pane_info in pairs(pane_infos) do
                if pane_info.active == 0 then
                    pane_candidate = pane_info
                end
            end
        else
            if pane_num == nil then
                vim.api.nvim_err_writeln("Please specify the tmux pane number (to check use tmux-prefix + q)")
            end
            if pane_infos[pane_num].active ~= 1 then
                pane_candidate = pane_infos[pane_num]
            else
                vim.api.nvim_err_writeln("pane num cannot be the active pane as this is the nvim pane")
            end

        end

        if pane_candidate then
            vim.pretty_print(check_if_python(pane_candidate))
        end
    end

end

connect_to_tmux(1)

return M
