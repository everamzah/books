--[[ Placeable Books by everamzah
	Copyright (C) 2016 James Stevenson
	LGPLv2.1+
	See LICENSE for more information ]]

-- Translation support
local S = minetest.get_translator("books")
local F = minetest.formspec_escape

local lpp = 14 -- Lines per book's page

local function copymeta(frommeta, tometa)
	tometa:from_table( frommeta:to_table() )
end

local function on_place(itemstack, placer, pointed_thing)
	if minetest.is_protected(pointed_thing.above, placer:get_player_name()) then
		-- TODO: record_protection_violation()
		return itemstack
	end

	local pointed_on_rightclick = minetest.registered_nodes[minetest.get_node(pointed_thing.under).name].on_rightclick
	if pointed_on_rightclick and not placer:get_player_control().sneak then
		return pointed_on_rightclick(pointed_thing.under, minetest.get_node(pointed_thing.under), placer, itemstack)
	end
	local data = itemstack:get_meta()
	local data_owner = data:get_string("owner")
	local stack = ItemStack({name = "default:book_closed"})
	if data and data_owner then
		copymeta(itemstack:get_meta(), stack:get_meta() )
	end
	local _, placed = minetest.item_place_node(stack, placer, pointed_thing, nil)
	if placed then
		itemstack:take_item()
	end
	return itemstack
end

local function after_place_node(pos, placer, itemstack, pointed_thing)

	local itemmeta = itemstack:get_meta()
	if itemmeta then
		local nodemeta = minetest.get_meta(pos)
		copymeta(itemmeta, nodemeta)
		nodemeta:set_string("infotext", S("@1\n\nby @2", itemmeta:get_string("title"),
			itemmeta:get_string("owner")))
	end
end

local function formspec_display(meta, player_name, pos)
	-- Courtesy of minetest_game/mods/default/craftitems.lua
	local title, text, owner = "", "", player_name
	local page, page_max, lines, string = 1, 1, {}, ""

	if meta:to_table().fields.owner then
		title = meta:get_string("title")
		text = meta:get_string("text")
		owner = meta:get_string("owner")

		for str in (text .. "\n"):gmatch("([^\n]*)[\n]") do
			lines[#lines+1] = str
		end

		if meta:to_table().fields.page then
			page = meta:to_table().fields.page
			page_max = meta:to_table().fields.page_max

			for i = ((lpp * page) - lpp) + 1, lpp * page do
				if not lines[i] then break end
				string = string .. lines[i] .. "\n"
			end
		end
	end

	local formspec
	if owner == player_name or (minetest.check_player_privs(player_name, {editor = true}) and minetest.get_player_by_name(player_name):get_wielded_item():get_name() == "books:admin_pencil" ) then
		formspec = "size[8,8]" ..
			default.gui_bg ..
			default.gui_bg_img ..
			"field[-4,-4;0,0;owner;"..F(S("Owner:"))..";" .. owner .. "]" ..

			"field[0.5,1;7.5,0;title;"..F(S("Title:"))..";" ..
				F(title) .. "]" ..
			"textarea[0.5,1.5;7.5,7;text;"..F(S("Contents:"))..";" ..
				F(text) .. "]" ..
			"button_exit[2.5,7.5;3,1;save;"..F(S("Save")).."]"
			-- TODO FIXME WE NEED TO SET A HIDDEN "owner" FIELD !!
	else
		formspec = "size[8,8]" ..
			default.gui_bg ..
			default.gui_bg_img ..
			"label[0.5,0.5;by " .. owner .. "]" ..
			"tablecolumns[color;text]" ..
			"tableoptions[background=#00000000;highlight=#00000000;border=false]" ..
			"table[0.4,0;7,0.5;title;#FFFF00," .. F(title) .. "]" ..
			"textarea[0.5,1.5;7.5,7;;" ..
				F(string ~= "" and string or text) .. ";]" ..
			"button[2.4,7.6;0.8,0.8;book_prev;<]" ..
			"label[3.2,7.7;"..F(S("Page @1 of @2", page, page_max)) .. "]" ..
			"button[4.9,7.6;0.8,0.8;book_next;>]"
	end

	minetest.show_formspec(player_name,
			"default:book_" .. minetest.pos_to_string(pos), formspec)
end

local function on_rightclick(pos, node, clicker, itemstack, pointed_thing)
	if node.name == "default:book_closed" then
		node.name = "default:book_open"
		minetest.swap_node(pos, node)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext",
				meta:get_string("text"))
	elseif node.name == "default:book_open" then
		local player_name = clicker:get_player_name()
		local meta = minetest.get_meta(pos)
		formspec_display(meta, player_name, pos)
	end
end

local function on_punch(pos, node, puncher, pointed_thing)
	if node.name == "default:book_open" then
		node.name = "default:book_closed"
		minetest.swap_node(pos, node)
		local meta = minetest.get_meta(pos)
		if meta:get_string("owner") ~= "" then
			meta:set_string("infotext",
					S("@1\n\nby @2", meta:get_string("title"),
					meta:get_string("owner")))
		end
	end
end

local function on_dig(pos, node, digger)
	if minetest.is_protected(pos, digger:get_player_name()) then
		-- TODO: record_protection_violation()
		return false
	end

	local nodemeta = minetest.get_meta(pos)
	local stack
	if nodemeta:get_string("owner") ~= "" then
		stack = ItemStack({name = "default:book_written"})
		copymeta(nodemeta, stack:get_meta() )
	else
		stack = ItemStack({name = "default:book"})
	end

	local adder = digger:get_inventory():add_item("main", stack)
	if adder then
		minetest.item_drop(adder, digger, digger:getpos())
	end
	minetest.remove_node(pos)
end



minetest.override_item("default:book", {on_place = on_place})

minetest.override_item("default:book_written", {on_place = on_place})

-- TODO: for book_open, book_written_open
minetest.register_node(":default:book_open", {
	description = S("Book Open"),
	inventory_image = "default_book.png",
	tiles = {
		"books_book_open_top.png",	-- Top
		"books_book_open_bottom.png",	-- Bottom
		"books_book_open_side.png",	-- Right
		"books_book_open_side.png",	-- Left
		"books_book_open_front.png",	-- Back
		"books_book_open_front.png"	-- Front
	},
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	use_texture_alpha = "clip",
	sunlight_propagates = true,
	node_box = {
		type = "fixed",
		fixed = {
			{-0.375, -0.47, -0.282, 0.375, -0.4125, 0.282}, -- Top
			{-0.4375, -0.5, -0.3125, 0.4375, -0.47, 0.3125},
		}
	},
	--groups = {attached_node = 1}, -- FIXME
	groups = {not_in_creative_inventory = 1},
	on_punch = on_punch,
	on_rightclick = on_rightclick,
})

-- TODO: for book_closed, book_written_closed
minetest.register_node(":default:book_closed", {
	description = S("Book Closed"),
	inventory_image = "default_book.png",
	tiles = {
		"books_book_closed_topbottom.png",	-- Top
		"books_book_closed_topbottom.png",	-- Bottom
		"books_book_closed_right.png",	-- Right
		"books_book_closed_left.png",	-- Left
		"books_book_closed_front.png^[transformFX",	-- Back
		"books_book_closed_front.png"	-- Front
	},
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	use_texture_alpha = "clip",
	sunlight_propagates = true,
	node_box = {
		type = "fixed",
		fixed = {
			{-0.25, -0.5, -0.3125, 0.25, -0.35, 0.3125},
		}
	},
	groups = {oddly_breakable_by_hand = 3, dig_immediate = 2, not_in_creative_inventory = 1}, --, attached_node = 1}, -- FIXME
	on_dig = on_dig,
	on_rightclick = on_rightclick,
	after_place_node = after_place_node,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname:sub(1, 13) ~= "default:book_" then
		return
	end

	if fields.save and fields.title ~= "" and fields.text ~= "" then
		local pos = minetest.string_to_pos(formname:sub(14))
		local node = minetest.get_node(pos)
		local meta = minetest.get_meta(pos)

		meta:set_string("title", fields.title)
		meta:set_string("text", fields.text)
		meta:set_string("owner", fields.owner or player:get_player_name() )
		meta:set_string("infotext", fields.text)
		meta:set_int("text_len", fields.text:len())
		meta:set_int("page", 1)
		meta:set_int("page_max", math.ceil((fields.text:gsub("[^\n]", ""):len() + 1) / lpp))
	elseif fields.book_next or fields.book_prev then
		local pos = minetest.string_to_pos(formname:sub(14))
		local node = minetest.get_node(pos)
		local meta = minetest.get_meta(pos)

		if fields.book_next then
			meta:set_int("page", meta:get_int("page") + 1)
			if meta:get_int("page") > meta:get_int("page_max") then
				meta:set_int("page", 1)
			end
		elseif fields.book_prev then
			meta:set_int("page", meta:get_int("page") - 1)
			if meta:get_int("page") == 0 then
				meta:set_int("page", meta:get_int("page_max"))
			end
		end

		formspec_display(meta, player:get_player_name(), pos)
	end
end)

if minetest.settings:get_bool("books.editor", false) then
	minetest.register_privilege("editor", S("Allow player to edit books with the Admin Pencil"))

	minetest.register_craftitem("books:admin_pencil", {
		description = S("Admin Pencil"),
		inventory_image = "books_admin_pencil.png",
		--[[
		-- FIXME - this does not work
		on_use = function(itemstack, user, pointed_thing)
			if not pointed_thing or not pointed_thing.under then
				return
			end

			local node = minetest.get_node(pointed_thing.under)

			if node.name == "default:book_open" then
				itemstack = itemstack:take_item()
			end

			return itemstack
		end,
		--]]
	})

	-- MAKE IT EXPENSIVE
	minetest.register_craft({
		output = "books:admin_pencil",
		recipe = {
			{"group:stick"},
			{"default:mese_crystal_fragment"},
			{"default:obsidian_shard"},
		}
	})
end
