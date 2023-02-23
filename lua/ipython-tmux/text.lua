local M = {}

---Returns the tree root of the buffer; if no buffer is specified of current buffer
---@param bufnr number?
---@return any
local get_root = function(bufnr)
    local parser = vim.treesitter.get_parser(bufnr, "python", {})
    local tree = parser:parse()[1]
    return tree:root()
end


---Find nearest previous comment with cell_comment as content
---@param bufnr number?
---@param cell_comment string
---@return { first_ln: number, last_ln: number? }|nil
local get_cell_query_lns = function(bufnr, cell_comment)
    local cur_line = vim.fn.line(".") - 1
    local escaped_cell_comment = cell_comment:gsub("%p", "%%%1")

    local query_string = string.format('((comment) @capture (#lua-match? @capture "^(%s)"))', escaped_cell_comment)

    local query = vim.treesitter.query.parse_query("python", query_string)

    local prev_diff_cmt_cur_ln_lowest = nil
    local prev_cmt_ln = nil

    local next_diff_cmt_cur_ln_lowest = nil
    local next_cmt_ln = nil

    local root = get_root(bufnr)

    for _, node in query:iter_captures(root, bufnr, 0, -1) do
        local _, _, cmt_line, _ = node:range()
        local cur_diff_ln = cur_line - cmt_line

        if not prev_diff_cmt_cur_ln_lowest and cur_diff_ln >= 0 then
            prev_diff_cmt_cur_ln_lowest = cur_diff_ln
            prev_cmt_ln = cmt_line
        elseif cur_diff_ln >= 0 and cur_diff_ln < prev_diff_cmt_cur_ln_lowest then
            prev_diff_cmt_cur_ln_lowest = cur_diff_ln
            prev_cmt_ln = cmt_line
        end

        if not next_diff_cmt_cur_ln_lowest and cur_diff_ln < 0 then
            next_diff_cmt_cur_ln_lowest = cur_diff_ln
            next_cmt_ln = cmt_line
        elseif cur_diff_ln < 0 and cur_diff_ln > next_diff_cmt_cur_ln_lowest then
            next_diff_cmt_cur_ln_lowest = cur_diff_ln
            next_cmt_ln = cmt_line
        end
    end

    if not prev_cmt_ln then
        vim.api.nvim_err_writeln(string.format(
            "No comment with cell comment format found! Please include a comment with the format '%s' before this line."
            , cell_comment))
        return
    end

    next_cmt_ln = next_cmt_ln or nil

    return { first_ln = prev_cmt_ln, last_ln = next_cmt_ln }
end

---Find nearest previous comment with cell_comment as content
---@param bufnr number?
---@param cell_comment string
---@return { first_ln: number, last_ln: number? }|nil
M.get_cell_lns = function(bufnr, cell_comment)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    if vim.bo[bufnr].filetype ~= "python" then
        vim.api.nvim_err_writeln("The buffer is not of filetype 'python'. Please make sure you open a python file")
    end

    local ln_table = get_cell_query_lns(bufnr, cell_comment)

    return ln_table
end

---Get the text in the cell
---@param bufnr number
---@param start_line number
---@param end_line number
---@return string[]
M.get_lns_text = function(bufnr, start_line, end_line)
    local cell_text = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
    local filtered_cell_text = {}
    for _, row in pairs(cell_text) do
        if row:match("%S") ~= nil then
            table.insert(filtered_cell_text, row)
        end
    end
    return filtered_cell_text
end

return M
