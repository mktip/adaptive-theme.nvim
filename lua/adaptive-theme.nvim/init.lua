local M = {}

local default_theme_handler = function(background)
	if background == "none" then
		return
	end
	vim.o.background = background
end

local theme_callback = function(theme_handler)
	local uv = vim.loop

	uv.new_async(vim.schedule_wrap(function(background)
		theme_handler(background)
	end))
end

local function adaptive_theme_watcher(callback)
	local ldbus = require("ldbus")
	local uv = vim.loop

	local AdaptiveColors = { LIGHT = "light", DARK = "dark", NONE = "none" }

	local function parse_msg(msg)
		local iter = ldbus.message.iter.new()

		assert(msg:iter_init(iter), "Message has no parameters")

		local result = AdaptiveColors.NONE

		for char in msg:get_signature():gmatch(".") do
			if char == "v" then
				local sub_iter = iter:recurse()
				local sigvalue = sub_iter:get_basic()

				assert(
					sub_iter:get_arg_type() == ldbus.types.uint32,
					"Expected adaptive theme state to be uint32, got " .. sub_iter:get_arg_type()
				)

				if sigvalue == 1 then -- 0 = light, 1 = dark
					result = AdaptiveColors.DARK
				else
					result = AdaptiveColors.LIGHT
				end
			end

			if not iter:next() then
				break
			end
		end

		return result
	end

	local conn = assert(ldbus.bus.get("session"))

	assert(ldbus.bus.add_match(
		conn,
		table.concat({
			"type='signal'",
			"interface='org.freedesktop.portal.Settings'",
			"member='SettingChanged'",
			"arg0='org.freedesktop.appearance'",
			"arg1='color-scheme'",
		}, ",")
	))
	conn:flush()

	while conn:read_write() do
		local msg = conn:pop_message()
		if msg:get_type() == "signal" then
			uv.async_send(callback, parse_msg(msg))
		end
	end
end

function M.setup(options)
	local uv = vim.loop

	M.theme_handler = options.theme_handler or default_theme_handler

	-- Start the watcher thread
	local watcher_thread = uv.new_thread(adaptive_theme_watcher, theme_callback(M.theme_handler))
end

return M
