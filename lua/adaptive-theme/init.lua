local M = {}

local default_theme_handler = function(background)
	if background == "none" then
		return
	end
	vim.o.background = background
end


local function theme_callback(theme_handler)
	local uv = vim.loop

	return uv.new_async(vim.schedule_wrap(function(background)
		theme_handler(background)
	end))
end

local function adaptive_theme_watcher(callback)
	local ldbus = require("ldbus")
	local uv = vim.loop

	local AdaptiveColors = { LIGHT = "light", DARK = "dark", NONE = "none" }

  local function read_initial_theme()
    local conn = assert ( ldbus.bus.get ( "session" ) )
    local msg = ldbus.message.new_method_call(
          "org.freedesktop.portal.Desktop",
          "/org/freedesktop/portal/desktop",
          "org.freedesktop.portal.Settings",
          "Read"
      )

    local iter = msg:iter_init_append()
    iter:append_basic("org.freedesktop.appearance")
    iter:append_basic("color-scheme")

    local resp = conn:send_with_reply_and_block(msg)

    if resp:iter_init():recurse():recurse():get_basic() == 1 then
      return AdaptiveColors.DARK
    else

    return AdaptiveColors.LIGHT

  end

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

  uv.async_send(callback, callback(read_initial_theme()))

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
	if not options then
		options = {}
	end

	local uv = vim.loop

	M.theme_handler = options.theme_handler or default_theme_handler

  -- Query current theme and run the theme handler initially
  local ldbus = require("ldbus")
  local conn = assert(ldbus.bus.get("session"))
  let msg = ldbus.message.new_method_call(
    "org.freedesktop.portal.Settings",
    "/org/freedesktop/portal/settings",
    "org.freedesktop.portal.Settings",
    "Get"
  )

  msg:append("org.freedesktop.appearance")

  local iter = ldbus.message.iter.new()
  msg:iter_init_append(iter)

  iter:append_basic("s", "color-scheme")

  print(msg)

	-- Start the watcher thread
	local watcher_thread = uv.new_thread(adaptive_theme_watcher, theme_callback(M.theme_handler))
end


return M
