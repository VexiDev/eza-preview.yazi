local M = {}

-- Helper function to display error notifications
local function fail(message)
    ya.notify {
        title = "Eza Preview",
        content = tostring(message),
        timeout = 2,
        level = "error"
    }
end

-- Toggle and check functions for view mode
local toggle_view_mode = ya.sync(function(state)
    state.tree = not state.tree
end)

local is_tree_view_mode = ya.sync(function(state)
    return state.tree or false
end)

-- Function to get the 'show_hidden' value from the context
local get_show_hidden = ya.sync(function()
    return cx.active.conf.show_hidden
end)

-- Function to parse and collect ignore patterns
local function get_ignore_patterns(directory, show_hidden)
    local patterns = {}
    local hidden_pattern_added = false

    local function parse_ignore_line(line)
        line = line:match("^%s*(.-)%s*$") -- Trim whitespace
        if line == "" or line:match("^#") or line:sub(1, 1) == '!' then
            return nil
        end

        local is_directory = line:sub(-1) == "/"
        if line:sub(1, 1) == '/' then
            line = line:sub(2)
        end
        if is_directory then
            return line .. "/**"
        else
            return line
        end
    end

    local function read_ignore_file(file_path)
        local file = io.open(file_path, "r")
        if file then
            for line in file:lines() do
                local pattern = parse_ignore_line(line)
                if pattern then
                    if pattern == ".*" then
                        hidden_pattern_added = true
                    end
                    table.insert(patterns, pattern)
                end
            end
            file:close()
        end
    end

    -- Read local and global .ezaignore files
    read_ignore_file(directory .. "/.ezaignore")
    read_ignore_file(os.getenv("HOME") .. "/.config/yazi/.ezaignore")

    if not show_hidden and not hidden_pattern_added then
        table.insert(patterns, ".*")
    end

    return patterns
end

-- Initialize the plugin by toggling the view mode
function M:setup()
    toggle_view_mode()
end

-- Entry point for the plugin; toggles view mode and resets scroll
function M:entry(_)
    toggle_view_mode()
    ya.manager_emit("seek", {0})
end

-- Handles scrolling within the preview
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

-- Main function to generate and display the preview
function M:peek()
    local args = {"-a", "--oneline", "--color=always", "--icons=always", "--group-directories-first", "--no-quotes"}

    if is_tree_view_mode() then
        table.insert(args, "-T")
    end

    local show_hidden = get_show_hidden()

    -- Always apply ignore patterns
    local patterns = get_ignore_patterns(tostring(self.file.url), show_hidden)
    if #patterns > 0 then
        table.insert(args, '-I="' .. table.concat(patterns, "|") .. '"')
    end

    table.insert(args, tostring(self.file.url))

    local eza_command = "eza " .. table.concat(args, " ")

    -- Debugging: display the eza command being used
    -- ya.notify {
    --     title = "Eza Command",
    --     content = eza_command,
    --     timeout = 0.5,
    --     level = "info"
    -- }

    -- Copy the command to the clipboard for debugging
    -- os.execute("echo '" .. eza_command .. "' | pbcopy")

    -- Execute the eza command using a shell
    local child = Command("/bin/sh"):args({"-c", eza_command}):stdout(Command.PIPED):stderr(Command.PIPED):spawn()

    local limit = self.area.h
    local lines = ""
    local num_lines = 0
    local num_skip = 0
    local empty_output = false

    repeat
        local line, event = child:read_line()
        if event == 1 then
            fail(event)
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

    if num_lines == 0 and not is_tree_view_mode() then
        empty_output = true
    elseif num_lines == 1 and is_tree_view_mode() then
        empty_output = true
    end

    child:start_kill()

    -- Update the view based on the output
    if self.skip > 0 and num_lines < limit then
        ya.manager_emit("peek", {
            tostring(math.max(0, self.skip - (limit - num_lines))),
            only_if = tostring(self.file.url),
            upper_bound = ""
        })
    elseif empty_output then
        ya.preview_widgets(self, {ui.Paragraph(self.area, {ui.Line("No items")}):align(ui.Paragraph.CENTER)})
    else
        ya.preview_widgets(self, {ui.Paragraph.parse(self.area, lines)})
        ya.manager_emit("reload", {
            only_if = tostring(self.file.url)
        })
    end
end

return M
