-- copy-uri.yazi — copy hovered/selected files to the clipboard as a text/uri-list
-- of file:// URIs (pasteable AS FILES into Telegram etc.). Reads the selection via
-- the API, then hands the raw paths to copy-uri.sh (which percent-encodes them).

local get_targets = ya.sync(function()
	local targets = {}
	if #cx.active.selected ~= 0 then
		for _, url in pairs(cx.active.selected) do
			table.insert(targets, tostring(url))
		end
	else
		local h = cx.active.current.hovered
		if h then
			table.insert(targets, tostring(h.url))
		end
	end
	return targets
end)

return {
	entry = function()
		local targets = get_targets()
		if #targets == 0 then
			return
		end

		-- build:  copy-uri.sh 'path1' 'path2' ...   (ya.quote shell-escapes each path)
		local args = {}
		for _, p in ipairs(targets) do
			table.insert(args, ya.quote(p))
		end
		local cmd = os.getenv("HOME") .. "/.config/yazi/copy-uri.sh " .. table.concat(args, " ")

		ya.emit("shell", { cmd, confirm = true })
		ya.notify({ title = "Clipboard", content = #targets .. " file(s) copied", timeout = 2 })
	end,
}
