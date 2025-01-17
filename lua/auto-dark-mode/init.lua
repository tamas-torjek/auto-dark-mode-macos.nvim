local utils = require("auto-dark-mode.utils")

---@type number
local timer_id
---@type boolean
local is_currently_dark_mode

---@type fun(): nil | nil
local set_dark_mode
---@type fun(): nil | nil
local set_light_mode

---@type number
local update_interval

---@type string
local query_command

-- Parses the query response for each system
---@param res string
---@return boolean
local function parse_query_response(res)
	return res == "Dark"
end

---@param callback fun(is_dark_mode: boolean)
local function check_is_dark_mode(callback)
	utils.start_job(query_command, {
		on_stdout = function(data)
			-- we only care about the first line of the response
			local is_dark_mode = parse_query_response(data[1])
			callback(is_dark_mode)
		end,
	})
end

---@param is_dark_mode boolean
local function change_theme_if_needed(is_dark_mode)
	if is_dark_mode == is_currently_dark_mode then
		return
	end

	is_currently_dark_mode = is_dark_mode
	if is_currently_dark_mode then
		set_dark_mode()
	else
		set_light_mode()
	end
end

local function start_check_timer()
	timer_id = vim.fn.timer_start(update_interval, function()
		check_is_dark_mode(change_theme_if_needed)
	end, { ["repeat"] = -1 })
end

local function init()
	query_command = "defaults read -g AppleInterfaceStyle"

	if vim.fn.has("unix") ~= 0 then
		if vim.loop.getuid() == 0 then
			query_command = "su - $SUDO_USER -c " .. query_command
		end
	end

	if type(set_dark_mode) ~= "function" or type(set_light_mode) ~= "function" then
		error([[

		Call `setup` first:

		require('auto-dark-mode').setup({
			set_dark_mode=function()
				vim.api.nvim_set_option_value('background', 'dark')
				vim.cmd('colorscheme gruvbox')
			end,
			set_light_mode=function()
				vim.api.nvim_set_option_value('background', 'light')
			end,
		})
		]])
	end

	check_is_dark_mode(change_theme_if_needed)
	start_check_timer()
end

local function disable()
	vim.fn.timer_stop(timer_id)
end

---@param options AutoDarkModeOptions
local function setup(options)
	options = options or {}

	---@param background string
	local function set_background(background)
		vim.api.nvim_set_option_value("background", background, {})
	end

	set_dark_mode = options.set_dark_mode or function()
		set_background("dark")
	end
	set_light_mode = options.set_light_mode or function()
		set_background("light")
	end
	update_interval = options.update_interval or 3000

	init()
end

return { setup = setup, init = init, disable = disable }
