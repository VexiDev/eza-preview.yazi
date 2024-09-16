
local M = {}
local ignore_enabled = true 

local function fail(s, ...)
    ya.notify { title = "Eza Preview", content = string.format(s, ...), timeout = 2, level = "error" }
end

local is_tree_view_mode = ya.sync(function(state, _)
    return state.tree
end)

local toggle_view_mode = ya.sync(function(state, _)
    if state.tree == nil then
        state.tree = false
    end
    state.tree = not state.tree
end)



-- Exposes the ignore filter toggle for mapping in ~/.config/yazi/keymap.toml
function M.toggle_ignore_filter()
    toggle_ignore_filter()
end

local function toggle_ignore_filter()
    ignore_enabled = not ignore_enabled
    ya.manager_emit("reload", { only_if = tostring(cx.active.current.file.url) })  -- Refresh Yazi window
    ya.notify { title = "Eza Ignore", content = "Ignore filter " .. (ignore_enabled and "enabled" or "disabled"), timeout = 1, level = "info" }
end

local function get_ignore_patterns(directory)
    local ignore_file = directory .. "/.ezaignore"
    local patterns = {}

    local function parse_gitignore_line(line)
        -- Remove leading and trailing whitespace
        line = line:match("^%s*(.-)%s*$")
        
        -- Skip empty lines and comments
        if line == "" or line:match("^#") then
            return nil
        end

        if line:sub(1, 1) == '!' then
            -- Negated patterns are not supported
            return nil
        end

        -- Remove leading '/'
        if line:sub(1, 1) == '/' then
            line = line:sub(2)
        end

        return line
    end

    local function read_ignore_file(file_path)
        local file = io.open(file_path, "r")
        if file then
            for line in file:lines() do
                local pattern = parse_gitignore_line(line)
                if pattern then
                    table.insert(patterns, pattern)
                end
            end
            file:close()
            return true
        else
            return false
        end
    end

    -- Try to read the local .ezaignore file
    local read_success = read_ignore_file(ignore_file)
    if not read_success then
        -- If no local .ezaignore, check for a global one
        local home = os.getenv("HOME")
        local global_ignore_file = home .. "/.config/yazi/.ezaignore"
        read_success = read_ignore_file(global_ignore_file)
    end

    return patterns
end



function M:setup()
    toggle_view_mode()
end

function M:entry(_)
    toggle_view_mode()
    ya.manager_emit("seek", { 0 })
end

function M:seek(units)
    local h = cx.active.current.hovered
    if h and h.url == self.file.url then
        local step = math.floor(units * self.area.h / 10)
        ya.manager_emit("peek", {
            math.max(0, cx.active.preview.skip + step),
            only_if = tostring(self.file.url),
            force = true
        })
    end
end

function M:peek()
    local args = {
        "-a",
        "--oneline",
        "--color=always",
        "--icons=always",
        "--group-directories-first",
        "--no-quotes",
    }
    
    if is_tree_view_mode() then
        table.insert(args, "-T")
    end
    
    -- Apply ignore patterns if ignore is enabled
    if ignore_enabled then
        -- get ignore patterns from .ezaignore file
        local patterns = get_ignore_patterns(tostring(self.file.url))

        -- If there are patterns, add them to the eza command
        if #patterns > 0 then
            local pattern_list = table.concat(patterns, "|")
            table.insert(args, "-I=\"" .. pattern_list .. "\"")
        end
    end

    -- For debugging: prints the eza command being used
    -- ya.notify { title = "Eza Command",
    --     content = "eza " .. table.concat(args, " "),
    --     timeout = 0.5,
    --     level = "info"
    -- }
    
    table.insert(args, tostring(self.file.url))

    -- Build the final eza command string for clipboard
    local eza_command = "eza " .. table.concat(args, " ")

    -- Copy the command to clipboard (macOS version using pbcopy)
    os.execute("echo '" .. eza_command .. "' | pbcopy")

    -- Replace '/bin/sh' with the path to your shell of choice
    -- Execute the eza command using a shell since Command() API does not correctly parse the `-I` argument in eza
    -- This is a workaround I'm sure there is probably a way to do this with the Command API
    local child = Command("/bin/sh")
        :args({ "-c", eza_command }) 
        :stdout(Command.PIPED)
        :stderr(Command.PIPED)
        :spawn()
        

    local limit = self.area.h
    local lines = ""
    local num_lines = 1
    local num_skip = 0
    local empty_output = false

    repeat
        local line, event = child:read_line()
        if event == 1 then
            fail(tostring(event))
        elseif event ~= 0 then
            break
        end

        if num_skip >= self.skip then
            lines = lines .. line
            num_lines = num_lines + 1
        else
            num_skip = num_skip + 1
        end
    until num_lines >= limit

    if num_lines == 1 and not is_tree_view_mode() then
        empty_output = true
    elseif num_lines == 2 and is_tree_view_mode() then
        empty_output = true
    end

    child:start_kill()

    -- For debugging: prints the output of the eza command
    -- ya.notify {
    --     title = "Eza Output",
    --     content = lines,
    --     timeout = 1,    
    --     level = "info"  
    -- }
    
    -- Ensure Yazi properly updates the view
    if self.skip > 0 and num_lines < limit then
        ya.manager_emit(
            "peek",
            { tostring(math.max(0, self.skip - (limit - num_lines))), only_if = tostring(self.file.url), upper_bound = "" }
        )
    elseif empty_output then
        ya.preview_widgets(self, {
            ui.Paragraph(self.area, { ui.Line("No items") })
                :align(ui.Paragraph.CENTER),
        })
    else
        -- Force UI widget redraw with the new output
        ya.preview_widgets(self, { ui.Paragraph.parse(self.area, lines) })
        -- Ensure proper refresh by reloading widget data
        ya.manager_emit("reload", { only_if = tostring(self.file.url) })
    end
end

return M
