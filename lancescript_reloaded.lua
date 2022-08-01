-- LANCESCRIPT RELOADED
script_version = 7.71
util.require_natives("1640181023")
gta_labels = require('all_labels')
all_labels = gta_labels.all_labels
sexts = gta_labels.sexts
ocoded_for = 1.61
is_loading = true
ls_debug = false
all_vehicles = {}
all_objects = {}
all_players = {}
all_peds = {}
all_pickups = {}
handle_ptr = memory.alloc(13*8)
player_cur_car = 0
good_guns = {0, 453432689, 171789620, 487013001, -1716189206, 1119849093}
util_alloc = memory.alloc(8)


store_dir = filesystem.store_dir() .. '\\lancescript_reloaded\\'
translations_dir = store_dir .. '\\translations\\'
resources_dir = filesystem.resources_dir() .. '\\lancescript_reloaded\\'
relative_translations_dir = "./store/lancescript_reloaded/translations/"

if not filesystem.is_dir(store_dir) then
    filesystem.mkdirs(store_dir)
end

if not filesystem.is_dir(translations_dir) then 
    filesystem.mkdirs(translations_dir)
end

function table_size(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

-- credit http://lua-users.org/wiki/StringRecipes
local function ends_with(str, ending)
    return ending == "" or str:sub(-#ending) == ending
 end

local translations
local translation_dir_files = {}
local just_translation_files = {}
for i, path in ipairs(filesystem.list_files(translations_dir)) do
    local file_str = path:gsub(translations_dir, '')
    translation_dir_files[#translation_dir_files + 1] = file_str
    if ends_with(file_str, '.lua') then
        just_translation_files[#just_translation_files + 1] = file_str
    end
end

local updated = false
if not table.contains(translation_dir_files, 'last_version.txt') then 
    updated = true
    local file = io.open(translations_dir .. "/last_version.txt",'w')
    file:write(script_version)
    file:close()
end

-- get version from file
local f = io.open(translations_dir .. "/last_version.txt",'r')
version_from_file = f:read('a')
f:close()
if tonumber(version_from_file) < script_version then
    local file = io.open(translations_dir .. "/last_version.txt",'w')
    file:write(script_version)
    file:close()
    updated = true
end

-- do not play with this unless you want shit breakin!
local need_default_translation
if not table.contains(translation_dir_files, 'english.lua') or updated then 
    need_default_translation = true
    async_http.init('gist.githubusercontent.com', '/xSetrox/013ad730bf38b9684151637356b1138c/raw', function(data)
        local file = io.open(translations_dir .. "/english.lua",'w')
        file:write(data)
        file:close()
        need_default_translation = false
    end, function()
        util.toast('! Failed to retrieve default translation table. Script must exit.')
        util.stop_script()
    end)
    async_http.dispatch()
else
    need_default_translation = false
end

while need_default_translation do 
    util.toast("Installing default/english translation...")
    util.yield()
end

local selected_lang_path = translations_dir .. 'selected_language.txt'
if not table.contains(translation_dir_files, 'selected_language.txt') then
    local file = io.open(selected_lang_path, 'w')
    file:write('english.lua')
    file:close()
end

-- read selected language 
local selected_lang_file = io.open(selected_lang_path, 'r')
local selected_language = selected_lang_file:read()
if not table.contains(translation_dir_files, selected_language) then
    util.toast(selected_language .. ' was not found. Defaulting to English.')
    translations = require(relative_translations_dir .. "english")
else
    translations = require(relative_translations_dir .. '\\' .. selected_language:gsub('.lua', ''))
end

-- backwards-compatibility
if selected_language ~= 'english.lua' then
    comparison_translations = require(relative_translations_dir .. "english")
    if table_size(comparison_translations) ~= table_size(translations) then
        if table.contains(translations, missing_translations) then
            util.toast(translations.missing_translations)
        else
            util.toast("[LANCESCRIPT] Some translations are missing. Some features will be replaced with their keys until this is resolved.")
        end
    end
end

-- log if verbose/debug mode is on
function ls_log(content)
    if ls_debug then
        util.toast(content)
        util.log(translations.script_name_for_log .. content)
    end
end

-- filesystem handling and logo 
if not filesystem.is_dir(resources_dir) then
    util.toast(translations.resource_dir_missing)
end

-- check online version
online_v = tonumber(NETWORK._GET_ONLINE_VERSION())
if online_v > ocoded_for then
    util.toast(translations.outdated_script_1 .. online_v .. translations.outdated_script_2 .. ocoded_for .. translations.outdated_script_3)
end

lancescript_logo = directx.create_texture(resources_dir .. 'lancescript_logo.png')
-- logo display
if SCRIPT_MANUAL_START then
    AUDIO.PLAY_SOUND(-1, "OPEN_WINDOW", "LESTER1A_SOUNDS", 0, 0, 1)
    logo_alpha = 0
    logo_alpha_incr = 0.01
    logo_alpha_thread = util.create_thread(function (thr)
        while true do
            logo_alpha = logo_alpha + logo_alpha_incr
            if logo_alpha > 1 then
                logo_alpha = 1
            elseif logo_alpha < 0 then 
                logo_alpha = 0
                util.stop_thread()
            end
            util.yield()
        end
    end)

    logo_thread = util.create_thread(function (thr)
        starttime = os.clock()
        local alpha = 0
        while true do
            directx.draw_texture(lancescript_logo, 0.14, 0.14, 0.5, 0.5, 0.5, 0.5, 0, 1, 1, 1, logo_alpha)
            timepassed = os.clock() - starttime
            if timepassed > 3 then
                logo_alpha_incr = -0.01
            end
            if logo_alpha == 0 then
                util.stop_thread()
            end
            util.yield()
        end
    end)
end

-- start organizing the MAIN lists (ones just at root level/right under it)
-- BEGIN SELF SUBSECTIONS
self_root = menu.list(menu.my_root(), translations.me, {translations.me_cmd}, translations.me_desc)
my_vehicle_root = menu.list(self_root, translations.my_vehicle, {translations.my_vehicle_cmd}, translations.my_vehicle_desc)
combat_root = menu.list(self_root, translations.combat, {translations.combat_cmd}, translations.combat_desc)
-- END SELF SUBSECTIONS
-- BEGIN ONLINE SUBSECTIONS
online_root = menu.list(menu.my_root(), translations.online, {translations.online_cmd}, translations.online_desc)
protections_root = menu.list(online_root, translations.protections, {translations.protections_cmd}, translations.protections_desc)
chat_presets_root = menu.list(online_root, translations.chatpresets, {translations.chatpresets_cmd}, translations.chatpresets_desc)
local players_shortcut_command = menu.ref_by_path('Players', 37)
menu.action(menu.my_root(), translations.players_shortcut, {}, translations.players_shortcut_desc, function(click_type)
    menu.trigger_command(players_shortcut_command)
end)

function get_stat_by_name(stat_name, character)
    if character then 
        stat_name = "MP" .. tostring(util.get_char_slot()) .. "_" .. stat_name 
    end
    local out = memory.alloc(8)
    STATS.STAT_GET_INT(MISC.GET_HASH_KEY(stat_name), out, -1)
    return memory.read_int(out)
end

function get_prostitutes_solicited(pid)
    return memory.read_int(memory.script_global(1853348 + 1 + (pid * 834) + 205 + 54))
end

function get_lapdances_amount(pid) 
    return memory.read_int(memory.script_global(1853348 + 1 + (pid * 834) + 205 + 55))
end
ap_root = menu.list(online_root, translations.all_players, {translations.all_players_cmd}, "")
apfriendly_root = menu.list(ap_root, translations.all_players_friendly, {translations.all_players_friendly_cmd}, "")
aphostile_root = menu.list(ap_root, translations.all_players_hostile, {translations.all_players_hostile_cmd}, "")
apneutral_root = menu.list(ap_root, translations.all_players_neutral, {translations.all_players_neutral_cmd}, "")
-- END ONLINE SUBSECTIONS
-- BEGIN ENTITIES SUBSECTION
entities_root = menu.list(menu.my_root(), translations.entities, {translations.entities_cmd}, translations.entities_desc)
peds_root = menu.list(entities_root, translations.peds, {translations.peds_cmd}, translations.peds_desc)
vehicles_root = menu.list(entities_root, translations.vehicles, {translations.vehicles_cmd}, translations.vehicles_desc)
pickups_root = menu.list(entities_root, translations.pickups, {translations.pickups_cmd}, translations.pickups_desc)
-- END ENTITIES SUBSECTION
world_root = menu.list(menu.my_root(), translations.world, {translations.world_cmd}, translations.world_desc)
tweaks_root = menu.list(menu.my_root(), translations.gametweaks, {translations.gametweaks_cmd}, translations.gametweaks_desc)
lancescript_root = menu.list(menu.my_root(), translations.misc, {translations.misc_cmd}, translations.misc_desc)
async_http.init("pastebin.com", "/raw/nrMdhHwE", function(result)
    menu.hyperlink(menu.my_root(), translations.discord, result, "")
end)
async_http.dispatch()

reap = false
menu.toggle(entities_root,  translations.reapermode, {translations.reapermode_cmd}, translations.reapermode_desc, function(on)
    reap = on
end)

-- entity-pool gathering handling
vehicle_uses = 0
ped_uses = 0
pickup_uses = 0
player_uses = 0
object_uses = 0
robustmode = false
reap = false
function mod_uses(type, incr)
    -- this func is a patch. every time the script loads, all the toggles load and set their state. in some cases this makes the _uses optimization negative and breaks things. this prevents that.
    if incr < 0 and is_loading then
        -- ignore if script is still loading
        ls_log("Not incrementing use var of type " .. type .. " by " .. incr .. "- script is loading")
        return
    end
    ls_log("Incrementing use var of type " .. type .. " by " .. incr)
    if type == "vehicle" then
        if vehicle_uses <= 0 and incr < 0 then
            return
        end
        vehicle_uses = vehicle_uses + incr
    elseif type == "pickup" then
        if pickup_uses <= 0 and incr < 0 then
            return
        end
        pickup_uses = pickup_uses + incr
    elseif type == "ped" then
        if ped_uses <= 0 and incr < 0 then
            return
        end
        ped_uses = ped_uses + incr
    elseif type == "player" then
        if player_uses <= 0 and incr < 0 then
            return
        end
        player_uses = player_uses + incr
    elseif type == "object" then
        if object_uses <= 0 and incr < 0 then
            return
        end
        object_uses = object_uses + incr
    end
end

-- UTILTITY FUNCTIONS


-- credit to vsus

function is_script_running(str)
    return SCRIPT._GET_NUMBER_OF_REFERENCES_OF_SCRIPT_WITH_NAME_HASH(util.joaat(str)) > 0
end

function request_game_script(str)
    if not SCRIPT.DOES_SCRIPT_EXIST(str) or is_script_running(str) then
        return false
    end
    if is_script_running(str) then
        return true
    end
    SCRIPT.REQUEST_SCRIPT(str)
    while not SCRIPT.HAS_SCRIPT_LOADED(str) do
        util.yield()
    end
end


---Credits to Nowiry
local function get_entity_owner(entity)
	local pEntity = entities.handle_to_pointer(entity)
	local addr = memory.read_long(pEntity + 0xD0)
	return (addr ~= 0) and memory.read_byte(addr + 0x49) or -1
end


function interpolate(y0, y1, perc)
	perc = perc > 1.0 and 1.0 or perc
	return (1 - perc) * y0 + perc * y1
end


function get_health_colour(perc)
	local result = {a = 255}
	local r, g, b
	if perc <= 0.5 then
		r = 1.0
		g = interpolate(0.0, 1.0, perc/0.5)
		b = 0.0
	else
		r = interpolate(1.0, 0, (perc - 0.5)/0.5)
		g = 1.0
		b = 0.0
	end
	result.r = math.ceil(r * 255)
	result.g = math.ceil(g * 255)
	result.b = math.ceil(b * 255)
	return result
end


function draw_marker(type, pos, dir, rot, scale, rotate, colour, txdDict, txdName)
    txdDict = txdDict or 0
    txdName = txdName or 0
    colour = colour or {r = 255, g = 255, b = 255, a = 255}
    GRAPHICS.DRAW_MARKER(type, pos.x, pos.y, pos.z, dir.x, dir.y, dir.z, rot.x, rot.y, rot.z, scale.x, scale.y, scale.z, colour.r, colour.g, colour.b, colour.a, false, true, 2, rotate, txdDict, txdName, false)
end


function get_distance_between_entities(entity, target)
	if not ENTITY.DOES_ENTITY_EXIST(entity) or not ENTITY.DOES_ENTITY_EXIST(target) then
		return 0.0
	end
	local pos = ENTITY.GET_ENTITY_COORDS(entity, true)
	return ENTITY.GET_ENTITY_COORDS(target, true):distance(pos)
end



function world_to_screen_coords(x, y, z)
    sc_x = memory.alloc(8)
    sc_y = memory.alloc(8)
    GRAPHICS.GET_SCREEN_COORD_FROM_WORLD_COORD(x, y, z, sc_x, sc_y)
    local ret = {
        x = memory.read_float(sc_x),
        y = memory.read_float(sc_y)
    }
    return ret
end

function is_entity_a_projectile(hash)
    local all_projectile_hashes = {
        util.joaat("w_ex_vehiclemissile_1"),
        util.joaat("w_ex_vehiclemissile_2"),
        util.joaat("w_ex_vehiclemissile_3"),
        util.joaat("w_ex_vehiclemissile_4"),
        util.joaat("w_ex_vehiclem,tar"),
        util.joaat("w_ex_apmine"),
        util.joaat("w_ex_arena_landmine_01b"),
        util.joaat("w_ex_birdshat"),
        util.joaat("w_ex_grenadefrag"),
        util.joaat("w_ex_grenadesmoke"),
        util.joaat("w_ex_molotov"),
        util.joaat("w_ex_pe"),
        util.joaat("w_ex_pipebomb"),
        util.joaat("w_ex_snowball"),
        util.joaat("w_lr_rpg_rocket"),
        util.joaat("w_lr_homing_rocket"),
        util.joaat("w_lr_firew,k_rocket"),
        util.joaat("xm_prop_x17_silo_rocket_01")
    }
    return table.contains(all_projectile_hashes, hash)
end

timed_thread = util.create_thread(function (thr)
    tlightstate = 0
    while true do
        if tlightstate < 3 then
            tlightstate = tlightstate + 1
        else
            tlightstate = 0
        end
        util.yield(100)
    end
end)

rgb_thread = util.create_thread(function (thr)
    local r = 255
    local g = 0
    local b = 0
    rgb = {255, 0, 0}
    while true do
        if not custom_rgb then
            if r > 0 and g < 255 and b == 0 then
                r = r - 1
                g = g + 1
            elseif r == 0 and g > 0 and b < 255 then
                g = g - 1
                b = b + 1
            elseif r < 255 and b > 0 then
                r = r + 1
                b = b - 1
            end
            rgb[1] = r
            rgb[2] = g
            rgb[3] = b
        else 
            rgb = {custom_r, custom_g, custom_b}
        end
        util.yield()
    end
end)


--https://stackoverflow.com/questions/34618946/lua-base64-encode
local b='/+9876543210zyxwvutsrqponmlkjihgfedcbaZYXWVUTSRQPONMLKJIHGFEDCBA'
function b64_enc(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end
--https://stackoverflow.com/questions/34618946/lua-base64-encode

-- decoding
function b64_dec(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
            return string.char(c)
    end))
end

friendtect = false
menu.toggle(protections_root, translations.friendtect, {translations.friendtect_cmd}, translations.friendtect_desc, function(on)
    friendtect = on
end)

menu.action(chat_presets_root, translations.dox, {}, translations.dox_desc, function(click_type)
    chat.send_message("${name}: ${ip} | ${geoip.city}, ${geoip.region}, ${geoip.country}", false, true, true)
end)

local chat_presets = {
    [translations.chat_preset_1_name] = translations.chat_preset_1_content,
    [translations.chat_preset_2_name] = translations.chat_preset_2_content,
    [translations.chat_preset_3_name] = translations.chat_preset_3_content,
    [translations.chat_preset_4_name] = translations.chat_preset_4_content,
    [translations.chat_preset_5_name] = translations.chat_preset_5_content
}
for k,v in pairs(chat_presets) do
    menu.action(chat_presets_root, k, {}, "\"" .. v .. "\"", function(click_type)
        chat.send_message(v, false, true, true)
    end)
end


memory.write_string(util_alloc, b64_dec("nZqek5CRmv=="))

function pid_to_handle(pid)
    NETWORK.NETWORK_HANDLE_FROM_PLAYER(pid, handle_ptr, 13)
    return handle_ptr
end

function get_model_size(hash)
    local minptr = memory.alloc(24)
    local maxptr = memory.alloc(24)
    MISC.GET_MODEL_DIMENSIONS(hash, minptr, maxptr)
    min = memory.read_vector3(minptr)
    max = memory.read_vector3(maxptr)
    local size = {}
    size['x'] = max['x'] - min['x']
    size['y'] = max['y'] - min['y']
    size['z'] = max['z'] - min['z']
    size['max'] = math.max(size['x'], size['y'], size['z'])
    return size
end

-- creative rgb vector from params (unused func??)
function to_rgb(r, g, b, a)
    local color = {}
    color.r = r
    color.g = g
    color.b = b
    color.a = a
    return color
end

-- credit to nowiry
function set_entity_face_entity(entity, target, usePitch)
    local pos1 = ENTITY.GET_ENTITY_COORDS(entity, false)
    local pos2 = ENTITY.GET_ENTITY_COORDS(target, false)
    local rel = v3.new(pos2)
    rel:sub(pos1)
    local rot = rel:toRot()
    if not usePitch then
        ENTITY.SET_ENTITY_HEADING(entity, rot.z)
    else
        ENTITY.SET_ENTITY_ROTATION(entity, rot.x, rot.y, rot.z, 2, 0)
    end
end

-- pre-made rgb's
black = to_rgb(0.0,0.0,0.0,1.0)
white = to_rgb(1.0,1.0,1.0,1.0)
red = to_rgb(1,0,0,1)
green = to_rgb(0,1,0,1)
blue = to_rgb(0.0,0.0,1.0,1.0)


-- RAYCAST SHIT

-- credits to nowiry
function get_offset_from_gameplay_camera(distance)
    local cam_rot = CAM.GET_GAMEPLAY_CAM_ROT(0)
    local cam_pos = CAM.GET_GAMEPLAY_CAM_COORD()
    local direction = v3.toDir(cam_rot)
    local destination = 
    { 
        x = cam_pos.x + direction.x * distance, 
        y = cam_pos.y + direction.y * distance, 
        z = cam_pos.z + direction.z * distance 
    }
    return destination
end

-- credit to nowiry i think
function get_offset_from_camera(distance, camera)
    local cam_rot = CAM.GET_CAM_ROT(camera, 0)
    local cam_pos = CAM.GET_CAM_COORD(camera)
    local direction = v3.toDir(cam_rot)
    local destination = 
    { 
        x = cam_pos.x + direction.x * distance, 
        y = cam_pos.y + direction.y * distance, 
        z = cam_pos.z + direction.z * distance 
    }
    return destination
end

-- also credit to nowiry i believe
function raycast_gameplay_cam(flag, distance)
    local ptr1, ptr2, ptr3, ptr4 = memory.alloc(), memory.alloc(), memory.alloc(), memory.alloc()
    local cam_rot = CAM.GET_GAMEPLAY_CAM_ROT(0)
    local cam_pos = CAM.GET_GAMEPLAY_CAM_COORD()
    local direction = v3.toDir(cam_rot)
    local destination = 
    { 
        x = cam_pos.x + direction.x * distance, 
        y = cam_pos.y + direction.y * distance, 
        z = cam_pos.z + direction.z * distance 
    }
    SHAPETEST.GET_SHAPE_TEST_RESULT(
        SHAPETEST.START_EXPENSIVE_SYNCHRONOUS_SHAPE_TEST_LOS_PROBE(
            cam_pos.x, 
            cam_pos.y, 
            cam_pos.z, 
            destination.x, 
            destination.y, 
            destination.z, 
            flag, 
            players.user_ped(), 
            1
        ), ptr1, ptr2, ptr3, ptr4)
    local p1 = memory.read_int(ptr1)
    local p2 = memory.read_vector3(ptr2)
    local p3 = memory.read_vector3(ptr3)
    local p4 = memory.read_int(ptr4)
    return {p1, p2, p3, p4}
end

-- i think nowiry gets credit here
function raycast_cam(flag, distance, cam)
    local ptr1, ptr2, ptr3, ptr4 = memory.alloc(), memory.alloc(), memory.alloc(), memory.alloc()
    local cam_rot = CAM.GET_CAM_ROT(cam, 0)
    local cam_pos = CAM.GET_CAM_COORD(cam)
    local direction = v3.toDir(cam_rot)
    local destination = 
    { 
        x = cam_pos.x + direction.x * distance, 
        y = cam_pos.y + direction.y * distance, 
        z = cam_pos.z + direction.z * distance 
    }
    SHAPETEST.GET_SHAPE_TEST_RESULT(
        SHAPETEST.START_EXPENSIVE_SYNCHRONOUS_SHAPE_TEST_LOS_PROBE(
            cam_pos.x, 
            cam_pos.y, 
            cam_pos.z, 
            destination.x, 
            destination.y, 
            destination.z, 
            flag, 
            -1, 
            1
        ), ptr1, ptr2, ptr3, ptr4)
    local p1 = memory.read_int(ptr1)
    local p2 = memory.read_vector3(ptr2)
    local p3 = memory.read_vector3(ptr3)
    local p4 = memory.read_int(ptr4)
    return {p1, p2, p3, p4}
end

-- set a player into a free seat in a vehicle, if any exist
function set_player_into_suitable_seat(ent)
    local driver = VEHICLE.GET_PED_IN_VEHICLE_SEAT(ent, -1)
    if not PED.IS_PED_A_PLAYER(driver) or driver == 0 then
        if driver ~= 0 then
            entities.delete(driver)
        end
        PED.SET_PED_INTO_VEHICLE(players.user_ped(), ent, -1)
    else
        for i=0, VEHICLE.GET_VEHICLE_MAX_NUMBER_OF_PASSENGERS(ent) do
            if VEHICLE.IS_VEHICLE_SEAT_FREE(ent, i) then
                PED.SET_PED_INTO_VEHICLE(players.user_ped(), ent, -1)
            end
        end
    end
end

-- aim info
local ent_types = {translations.ped_type_1, translations.ped_type_2, translations.ped_type_3, translations.ped_type_4}
function get_aim_info()
    local outptr = memory.alloc(4)
    local success = PLAYER.GET_ENTITY_PLAYER_IS_FREE_AIMING_AT(players.user(), outptr)
    local info = {}
    if success then
        local ent = memory.read_int(outptr)
        if not ENTITY.DOES_ENTITY_EXIST(ent) then
            info["ent"] = 0
        else
            info["ent"] = ent
        end
        if ENTITY.GET_ENTITY_TYPE(ent) == 1 then
            local veh = PED.GET_VEHICLE_PED_IS_IN(ent, false)
            if veh ~= 0 then
                if VEHICLE.GET_PED_IN_VEHICLE_SEAT(veh, -1) then
                    ent = veh
                    info['ent'] = ent
                end
            end
        end
        info["hash"] = ENTITY.GET_ENTITY_MODEL(ent)
        info["health"] = ENTITY.GET_ENTITY_HEALTH(ent)
        info["type"] = ent_types[ENTITY.GET_ENTITY_TYPE(ent)+1]
        info["speed"] = math.floor(ENTITY.GET_ENTITY_SPEED(ent))
    else
        info['ent'] = 0
    end
    return info
end

-- shorthand for running commands
function kick_from_veh(pid)
    menu.trigger_commands("vehkick" .. PLAYER.GET_PLAYER_NAME(pid))
end

-- npc carjack algorithm 3.0
function npc_jack(target, nearest)
    npc_jackthr = util.create_thread(function(thr)
        local player_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(target)
        local last_veh = PED.GET_VEHICLE_PED_IS_IN(player_ped, true)
        kick_from_veh(target)
        local st = os.time()
        while not VEHICLE.IS_VEHICLE_SEAT_FREE(last_veh, -1) do 
            if os.time() - st >= 10 then
                util.toast(translations.failed_to_free_seat)
                util.stop_thread()
            end
            util.yield()
        end
        local hash = 0x9C9EFFD8
        request_model_load(hash)
        local coords = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(player_ped, -2.0, 0.0, 0.0)
        local ped = entities.create_ped(28, hash, coords, 30.0)
        ENTITY.SET_ENTITY_INVINCIBLE(ped, true)
        PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(ped, true)
        PED.SET_PED_FLEE_ATTRIBUTES(ped, 0, false)
        PED.SET_PED_COMBAT_ATTRIBUTES(ped, 46, true)
        PED.SET_PED_INTO_VEHICLE(ped, last_veh, -1)
        VEHICLE.SET_VEHICLE_ENGINE_ON(last_veh, true, true, false)
        TASK.TASK_VEHICLE_DRIVE_TO_COORD(ped, last_veh, math.random(1000), math.random(1000), math.random(100), 100, 1, ENTITY.GET_ENTITY_MODEL(last_veh), 786996, 5, 0)
        util.stop_thread()
    end)
end

-- gets a random pedestrian
function get_random_ped()
    peds = entities.get_all_peds_as_handles()
    npcs = {}
    valid = 0
    for k,p in pairs(peds) do
        if p ~= nil and not PED.IS_PED_A_PLAYER(p) then
            table.insert(npcs, p)
            valid = valid + 1
        end
    end
    return npcs[math.random(valid)]
end

function spawn_object_in_front_of_ped(ped, hash, ang, room, zoff, setonground)
    coords = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(ped, 0.0, room, zoff)
    request_model_load(hash)
    hdng = ENTITY.GET_ENTITY_HEADING(ped)
    coords.x = coords['x']
    coords.y = coords['y']
    coords.z = coords['z']
    new = OBJECT.CREATE_OBJECT_NO_OFFSET(hash, coords['x'], coords['y'], coords['z'], true, false, false)
    ENTITY.SET_ENTITY_HEADING(new, hdng+ang)
    if setonground then
        OBJECT.PLACE_OBJECT_ON_GROUND_PROPERLY(new)
    end
    return new
end

-- entity ownership forcing
function request_control_of_entity(ent)
    if not NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(ent) and util.is_session_started() then
        local netid = NETWORK.NETWORK_GET_NETWORK_ID_FROM_ENTITY(ent)
        NETWORK.SET_NETWORK_ID_CAN_MIGRATE(netid, true)
        local st_time = os.time()
        while not NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(ent) do
            -- intentionally silently fail, otherwise we are gonna spam the everloving shit out of the user
            if os.time() - st_time >= 5 then
                ls_log("Failed to request entity control in 5 seconds (entity " .. ent .. ")")
                break
            end
            NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(ent)
            util.yield()
        end
    end
end

-- model load requesting, very important
function request_model_load(hash)
    request_time = os.time()
    if not STREAMING.IS_MODEL_VALID(hash) then
        return
    end
    STREAMING.REQUEST_MODEL(hash)
    while not STREAMING.HAS_MODEL_LOADED(hash) do
        if os.time() - request_time >= 10 then
            break
        end
        util.yield()
    end
end

-- texure loading
function request_texture_dict_load(dict_name)
    request_time = os.time()
    GRAPHICS.REQUEST_STREAMED_TEXTURE_DICT(dict_name, true)
    while not GRAPHICS.HAS_STREAMED_TEXTURE_DICT_LOADED(dict_name) do
        if os.time() - request_time >= 10 then
            break
        end
        util.yield()
    end
end

-- get where the ground is (very broken func tbh)
function get_ground_z(coords)
    local start_time = os.time()
    while true do
        if os.time() - start_time >= 5 then
            ls_log("Failed to get ground Z in 5 seconds.")
            return nil
        end
        local success, est = util.get_ground_z(coords['x'], coords['y'], coords['z']+2000)
        if success then
            return est
        end
        util.yield()
    end
end

-- gets coords of waypoint
function get_waypoint_coords()
    local coords = HUD.GET_BLIP_COORDS(HUD.GET_FIRST_BLIP_INFO_ID(8))
    if coords['x'] == 0 and coords['y'] == 0 and coords['z'] == 0 then
        return nil
    else
        local estimate = get_ground_z(coords)
        if estimate then
            coords['z'] = estimate
        end
        return coords
    end
end

-- ME/SELF
ped_flags = {}

local ls_driveonair
walkonwater = false
menu.toggle(self_root, translations.walk_on_water, {translations.walk_on_water_cmd}, translations.walk_on_water_desc, function(on)
    walkonwater = on
    if on then
        menu.set_value(ls_driveonair, false)
    end
end)


menu.action(self_root, translations.set_ped_flag, {translations.set_ped_flag_cmd}, translations.set_ped_flag_desc, function(click_type)
    util.toast(translations.ped_input_flag_int)
    menu.show_command_box(translations.set_ped_flag_cmd .. " ")
end, function(on_command)
    local pflag = tonumber(on_command)
    if ped_flags[pflag] == true then
        ped_flags[pflag] = false
        util.toast(translations.ped_flag_false)
    else
        ped_flags[pflag] = true
        util.toast(translations.ped_flag_true)
    end
end)

menu.toggle(self_root, translations.burning_man, {translations.burning_man_desc_cmd}, translations.burning_man_desc, function(on)
    ped_flags[430] = on
    if on then
        FIRE.START_ENTITY_FIRE(players.user_ped())
        ENTITY.SET_ENTITY_PROOFS(players.user_ped(), false, true, false, false, false, false, 0, false) -- fire proof
    else
        FIRE.STOP_ENTITY_FIRE(players.user_ped())
        ENTITY.SET_ENTITY_PROOFS(players.user_ped(), false, false, false, false, false, false, 0, false)
    end
end)


-- MY VEHICLE
my_vehicle_movement_root = menu.list(my_vehicle_root, translations.movement, {translations.movement_cmd}, translations.movement_desc)

speedometer_plate_root = menu.list(my_vehicle_root, translations.speed_plate_root, {translations.speed_plate_root_cmd}, translations.speed_plate_desc)
mph_plate = false
menu.toggle(speedometer_plate_root, translations.speed_plate_root, {translations.speed_plate_cmd}, translations.speed_plate_desc, function(on)
    mph_plate = on
    if on then
        if player_cur_car ~= 0 then
            original_plate = VEHICLE.GET_VEHICLE_NUMBER_PLATE_TEXT(player_cur_car)
        else
            util.toast(translations.sp_not_in_veh)
            original_plate = translations.lance
        end
    else
        if player_cur_car ~= 0 then
            if original_plate == nil then
                original_plate = translations.lance
            end
            VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(player_cur_car, original_plate)
        end
    end
end)

mph_unit = translations.kph
local unit_options = {translations.kph, translations.mph}
menu.list_action(speedometer_plate_root, translations.speed_unit, {translations.speed_unit_cmd}, "", unit_options, function(index, value, click_type)
    mph_unit = value
end)

-- BEGIN MOVEMENT ROOT
dow_block = 0
driveonwater = false
local ls_driveonwater = menu.toggle(my_vehicle_movement_root, translations.drive_on_water, {translations.drive_on_water_cmd}, "", function(on)
    driveonwater = on
    if on then
        if driveonair then
            menu.set_value(ls_driveonair, false)
            util.toast(translations.drive_on_air_autooff)
        end
    else
        if not driveonair and not walkonwater then
            ENTITY.SET_ENTITY_COORDS_NO_OFFSET(dow_block, 0, 0, 0, false, false, false)
        end
    end
end)

doa_ht = 0
driveonair = false
ls_driveonair = menu.toggle(my_vehicle_movement_root, translations.drive_on_air, {translations.drive_on_air_cmd}, "", function(on)
    driveonair = on
    if on then
        local pos = ENTITY.GET_ENTITY_COORDS(players.user_ped(), true)
        doa_ht = pos['z']
        util.toast(translations.drive_on_air_instructions)
        if driveonwater then
            menu.set_value(ls_driveonwater, false)
            util.toast(translations.drive_on_water_autooff)
        end
    end
end)

menu.toggle_loop(my_vehicle_movement_root, translations.vehicle_strafe, {translations.vehicle_strafe_cmd}, translations.vehicle_strafe_desc, function(toggle)
    if player_cur_car ~= 0 then
        local rot = ENTITY.GET_ENTITY_ROTATION(player_cur_car, 0)
        if PAD.IS_CONTROL_PRESSED(175, 175) then
            ENTITY.APPLY_FORCE_TO_ENTITY(player_cur_car, 1, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, true, true, true, false, true)
            ENTITY.SET_ENTITY_ROTATION(player_cur_car, rot['x'], rot['y'], rot['z'], 0, true)
        end
        if PAD.IS_CONTROL_PRESSED(174, 174) then
            ENTITY.APPLY_FORCE_TO_ENTITY(player_cur_car, 1, -1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, true, true, true, false, true)
            ENTITY.SET_ENTITY_ROTATION(player_cur_car, rot['x'], rot['y'], rot['z'], 0, true)
        end
    end
end)

vjumpforce = 20
vslamforce = 20
menu.toggle_loop(my_vehicle_movement_root, translations.vehicle_jump, {translations.vehicle_jump_cmd}, translations.vehicle_jump_desc, function(toggle)
    if player_cur_car ~= 0 then
        if PAD.IS_CONTROL_JUST_PRESSED(86,86) then
            ENTITY.APPLY_FORCE_TO_ENTITY(player_cur_car, 1, 0.0, 0.0, vjumpforce, 0.0, 0.0, 0.0, 0, true, true, true, false, true)
        end
    end
end)


menu.toggle_loop(my_vehicle_movement_root, translations.vehicle_slam, {translations.vehicle_slam_cmd}, translations.vehicle_slam_desc, function(toggle)
    if player_cur_car ~= 0 then
        if PAD.IS_CONTROL_JUST_PRESSED(36,36) then
            ENTITY.APPLY_FORCE_TO_ENTITY(player_cur_car, 1, 0.0, 0.0, -vslamforce, 0.0, 0.0, 0.0, 0, true, true, true, false, true)
        end
    end
end)


menu.slider(my_vehicle_movement_root, translations.vehicle_jump_force, {translations.vehicle_jump_force_cmd}, "", 1, 300, 20, 1, function(s)
    vjumpforce = s
  end)


menu.slider(my_vehicle_movement_root, translations.vehicle_slam_force, {translations.vehicle_slam_force_cmd}, "", 1, 300, 50, 1, function(s)
    vslamforce = s
  end)

menu.toggle_loop(my_vehicle_movement_root, translations.stick_to_ground, {translations.stick_to_ground_cmd}, translations.stick_to_ground_desc, function(on)
    if player_cur_car ~= 0 then
        local vel = ENTITY.GET_ENTITY_VELOCITY(player_cur_car)
        vel['z'] = -vel['z']
        ENTITY.APPLY_FORCE_TO_ENTITY(player_cur_car, 2, 0, 0, -50 -vel['z'], 0, 0, 0, 0, true, false, true, false, true)
        --ENTITY.SET_ENTITY_VELOCITY(player_cur_car, vel['x'], vel['y'], -0.2)
    end
end)

menu.action(my_vehicle_movement_root, translations.vehicle_180, {translations.vehicle_180_cmd}, translations.vehicle_180_desc, function(click_type)
    if player_cur_car ~= 0 then
        local rot = ENTITY.GET_ENTITY_ROTATION(player_cur_car, 0)
        local vel = ENTITY.GET_ENTITY_VELOCITY(player_cur_car)
        ENTITY.SET_ENTITY_ROTATION(player_cur_car, rot['x'], rot['y'], rot['z']+180, 0, true)
        ENTITY.SET_ENTITY_VELOCITY(player_cur_car, -vel['x'], -vel['y'], vel['z'])
    end
end)

v_f_previous_car = 0
vflyspeed = 100
v_fly = false
v_f_plane = 0

menu.slider(my_vehicle_movement_root, translations.vehicle_fly_speed, {translations.vehicle_fly_speed_cmd}, "", 1, 3000, 100, 1, function(s)
    vflyspeed = s
end)

local ls_vehiclefly = menu.toggle_loop(my_vehicle_movement_root, translations.vehicle_fly, {translations.vehicle_fly_cmd}, translations.vehicle_fly_desc, function(on)
    if player_cur_car ~= 0 and PED.IS_PED_IN_ANY_VEHICLE(players.user_ped(), true) then
        ENTITY.SET_ENTITY_MAX_SPEED(player_cur_car, vflyspeed)
        local c = CAM.GET_GAMEPLAY_CAM_ROT(0)
        CAM._DISABLE_VEHICLE_FIRST_PERSON_CAM_THIS_FRAME()
        ENTITY.SET_ENTITY_ROTATION(player_cur_car, c.x, c.y, c.z, 0, true)
        any_c_pressed = false
        --W
        local x_vel = 0.0
        local y_vel = 0.0
        local z_vel = 0.0
        if PAD.IS_CONTROL_PRESSED(32, 32) then
            x_vel = vflyspeed
        end 
        --A
        if PAD.IS_CONTROL_PRESSED(63, 63) then
            y_vel = -vflyspeed
        end
        --S
        if PAD.IS_CONTROL_PRESSED(33, 33) then
            x_vel = -vflyspeed
        end
        --D
        if PAD.IS_CONTROL_PRESSED(64, 64) then
            y_vel = vflyspeed
        end
        if x_vel == 0.0 and y_vel == 0.0 and z_vel == 0.0 then
            ENTITY.SET_ENTITY_VELOCITY(player_cur_car, 0.0, 0.0, 0.0)
        else
            local angs = ENTITY.GET_ENTITY_ROTATION(player_cur_car, 0)
            local spd = ENTITY.GET_ENTITY_VELOCITY(player_cur_car)
            if angs.x > 1.0 and spd.z < 0 then
                z_vel = -spd.z 
            else
                z_vel = 0.0
            end
            ENTITY.APPLY_FORCE_TO_ENTITY(player_cur_car, 3, y_vel, x_vel, z_vel, 0.0, 0.0, 0.0, 0, true, true, true, false, true)
        end
    end
end, function()
    if player_cur_car ~= 0 then
        ENTITY.SET_ENTITY_HAS_GRAVITY(player_cur_car, true)
    end
end
)

-- END MOVEMENT ROOT

menu.action(my_vehicle_root, translations.force_leave_vehicle, {translations.force_leave_vehicle_cmd}, translations.force_leave_vehicle_desc, function(click_type)
    TASK.CLEAR_PED_TASKS_IMMEDIATELY(players.user_ped())
    TASK.TASK_LEAVE_ANY_VEHICLE(players.user_ped(), 0, 16)
end)

menu.click_slider(my_vehicle_root, translations.set_dirt_level, {translations.set_dirt_level_cmd}, "", 0, 15, 0, 1, function(s)
    if player_cur_car ~= 0 then
        VEHICLE.SET_VEHICLE_DIRT_LEVEL(player_cur_car, s)
    end
end)

menu.click_slider(my_vehicle_root, translations.stack_vertically, {translations.stack_vertically_cmd}, "", 1, 10, 3, 1, function(s)
    if player_cur_car ~= 0 then
        old_veh = player_cur_car
        for i=1, s do
            local c = ENTITY.GET_ENTITY_COORDS(old_veh, false)
            local mdl = ENTITY.GET_ENTITY_MODEL(player_cur_car)
            local size = get_model_size(mdl)
            local r = ENTITY.GET_ENTITY_ROTATION(old_veh, 0)
            new_veh = entities.create_vehicle(mdl, ENTITY.GET_ENTITY_COORDS(players.user_ped(), true), ENTITY.GET_ENTITY_HEADING(old_veh))
            ENTITY.ATTACH_ENTITY_TO_ENTITY(new_veh, old_veh, 0, 0.0, 0.0, size.z, 0.0, 0.0, 0.0, true, false, falsmy_e, false, 0, true)
            old_veh = new_veh
        end
    end
end)

menu.click_slider(my_vehicle_root, translations.stack_horizontally, {translations.stack_horizontally_cmd}, "", 1, 10, 3, 1, function(s)
    if player_cur_car ~= 0 then
        for i=1, s do
            main_veh = player_cur_car
            local c = ENTITY.GET_ENTITY_COORDS(main_veh, false)
            local mdl = ENTITY.GET_ENTITY_MODEL(main_veh)
            local size = get_model_size(mdl)
            local r = ENTITY.GET_ENTITY_ROTATION(main_veh, 0)
            left_new = entities.create_vehicle(mdl, ENTITY.GET_ENTITY_COORDS(players.user_ped(), true), ENTITY.GET_ENTITY_HEADING(main_veh))
            ENTITY.ATTACH_ENTITY_TO_ENTITY(left_new, main_veh, 0, -size.x*i, 0.0, 0.0, 0.0, 0.0, 0.0, true, false, false, false, 0, true)
            right_new = entities.create_vehicle(mdl, ENTITY.GET_ENTITY_COORDS(players.user_ped(), true), ENTITY.GET_ENTITY_HEADING(main_veh))
            ENTITY.ATTACH_ENTITY_TO_ENTITY(right_new, main_veh, 0, size.x*i, 0.0, 0.0, 0.0, 0.0, 0.0, true, false, false, false, 0, true)
        end
    end
end)

cinematic_autod = false
menu.toggle(my_vehicle_root, translations.cinematic_auto_drive, {translations.cinematic_auto_drive_cmd}, translations.cinematic_auto_drive_desc, function(on)
    cinematic_autod = on
end)

menu.action(my_vehicle_root, translations.break_rudder, {translations.break_rudder_cmd}, translations.break_rudder_desc, function(click_type)
    if player_cur_car ~= 0 then
        VEHICLE.SET_VEHICLE_RUDDER_BROKEN(player_cur_car, true)
    end
end)

menu.toggle_loop(my_vehicle_root, translations.force_spawn_countermeasures, {translations.force_spawn_countermeasures_cmd}, translations.force_spawn_countermeasures_desc, function(on)
    if PAD.IS_CONTROL_PRESSED(46, 46) then
        local target = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(players.user_ped(), math.random(-5, 5), -30.0, math.random(-5, 5))
        --MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(target['x'], target['y'], target['z'], target['x'], target['y'], target['z'], 300.0, true, -1355376991, players.user_ped(), true, false, 100.0)
        MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(target['x'], target['y'], target['z'], target['x'], target['y'], target['z'], 100.0, true, 1198879012, players.user_ped(), true, false, 100.0)
    end
end)

--SET_VEHICLE_DOOR_CONTROL

tesla_ped = 0
menu.action(my_vehicle_root, translations.tesla_summon, {translations.tesla_summon_cmd}, translations.tesla_summon_desc, function(click_type)
    lastcar = PLAYER.GET_PLAYERS_LAST_VEHICLE()
    if lastcar ~= 0 then
        local plyr = PLAYER.PLAYER_PED_ID()
        local coords = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(plyr, 0.0, 5.0, 0.0)
        coords.x = coords['x']
        coords.y = coords['y']
        coords.z = coords['z']
        local phash = -67533719
        request_model_load(phash)
        tesla_ped = entities.create_ped(32, phash, coords, ENTITY.GET_ENTITY_HEADING(plyr))
        tesla_blip = HUD.ADD_BLIP_FOR_ENTITY(tesla_ped)
        HUD.SET_BLIP_COLOUR(tesla_blip, 7)
        ENTITY.SET_ENTITY_VISIBLE(tesla_ped, false, 0)
        ENTITY.SET_ENTITY_INVINCIBLE(tesla_ped, true)
        PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(tesla_ped, true)
        PED.SET_PED_FLEE_ATTRIBUTES(tesla_ped, 0, false)
        VEHICLE.SET_VEHICLE_DOORS_LOCKED_FOR_ALL_PLAYERS(lastcar, true)
        PED.SET_PED_INTO_VEHICLE(tesla_ped, lastcar, -1)
        TASK.TASK_VEHICLE_DRIVE_TO_COORD_LONGRANGE(tesla_ped, lastcar, coords['x'], coords['y'], coords['z'], 300.0, 786996, 5)
    end
end)
--SET_RADIO_TRACK

menu.toggle_loop(my_vehicle_movement_root, translations.hold_shift_to_drift, {translations.hold_shift_to_drift_cmd}, translations.hold_shift_to_drift_desc, function(on)
    if PAD.IS_CONTROL_PRESSED(21, 21) then
        VEHICLE.SET_VEHICLE_REDUCE_GRIP(player_cur_car, true)
        VEHICLE._SET_VEHICLE_REDUCE_TRACTION(player_cur_car, 0.0)
    else
        VEHICLE.SET_VEHICLE_REDUCE_GRIP(player_cur_car, false)
    end
end)

menu.toggle_loop(my_vehicle_movement_root, translations.horn_boost, {translations.horn_boost_cmd}, translations.horn_boost_desc, function(on)
    if player_cur_car ~= 0 then
        VEHICLE.SET_VEHICLE_ALARM(player_cur_car, false)
        if AUDIO.IS_HORN_ACTIVE(player_cur_car) then
            ENTITY.APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(player_cur_car, 1, 0.0, 1.0, 0.0, true, true, true, true)
        end
    end
end)

-- COMBAT
-- COMBAT-RELATED toggles, actions, and functionality

-- ## silent aimbot
silent_aimbotroot = menu.list(combat_root, translations.silent_aimbot, {translations.silent_aimbot_root_cmd}, translations.silent_aimbot_desc)
kill_auraroot = menu.list(combat_root, translations.kill_aura, {translations.kill_aura_root_cmd}, translations.kill_aura_desc)
weapons_root = menu.list(combat_root, translations.spec_weapons, {translations.spec_weapons_cmd}, translations.spec_weapons_desc)

-- preload the textures
menu.toggle_loop(combat_root, translations._3d_crosshair, {translations._3d_crosshair_cmd}, translations._3d_crosshair_cmd, function(on)
    request_texture_dict_load('visualflow')
    local rc = raycast_gameplay_cam(-1, 10000.0)[2]
    local c = ENTITY.GET_ENTITY_COORDS(players.user_ped(), true)
    local dist = MISC.GET_DISTANCE_BETWEEN_COORDS(rc.x, rc.y, rc.z, c.x, c.y, c.z, false)
    local dir = v3.toDir(CAM.GET_GAMEPLAY_CAM_ROT(0))
    size = {}
    size.x = 0.5+(dist/50)
    size.y = 0.5+(dist/50)
    size.z = 0.5+(dist/50)
    GRAPHICS.DRAW_MARKER(3, rc.x, rc.y, rc.z, 0.0, 0.0, 0.0, 0.0, 90.0, 0.0, size.y, 1.0, size.x, 255, 255, 255, 50, false, true, 2, false, 'visualflow', 'crosshair')
end)

kill_aura = false
menu.toggle(kill_auraroot, translations.kill_aura, {translations.kill_aura_cmd},  translations.kill_aura_desc, function(on)
    kill_aura = on
    mod_uses("ped", if on then 1 else -1)
end)

kill_aura_peds = false
menu.toggle(kill_auraroot, translations.kill_peds, {translations.kill_peds_cmd}, "", function(on)
    kill_aura_peds = on
end)

kill_aura_players = false
menu.toggle(kill_auraroot, translations.kill_players, {translations.kill_players_cmd}, "", function(on)
    kill_aura_players = on
end)

kill_aura_friends = false
menu.toggle(kill_auraroot, translations.target_friends, {translations.ka_target_friends}, "", function(on)
    kill_aura_friends= on
end)


kill_aura_dist = 20
menu.slider(kill_auraroot, translations.kill_aura_radius, {translations.kill_aura_radius_cmd}, "", 1, 100, 20, 1, function(s)
    kill_aura_dist = s
end)


-- entity gun
entity_gun = menu.list(weapons_root, translations.entity_gun, {translations.entity_gun_root_cmd}, translations.entity_gun_desc)
entgun = false
shootent = -422877666
menu.toggle(entity_gun, translations.entity_gun, {translations.entity_gun_cmd}, translations.entity_gun_desc, function(on)
    entgun = on
end)

custom_egun_model = "prop_tool_blowtorch"
menu.text_input(entity_gun, translations.custom_eg_model, {translations.custom_eg_model_cmd}, translations.custom_eg_model_desc, function(on_input)
    custom_egun_model = on_input
end, "prop_tool_blowtorch")


local entity_hashes = {-422877666, -717142483, util.joaat("prop_paints_can07")}
local entity_options = {translations.dildo, translations.soccer_ball, translations.bucket, translations.custom}
menu.list_action(entity_gun, translations.entity_gun_selection, {translations.entity_gun_selection_cmd}, "", entity_options, function(index, value, click_type)
    if index < 4 then
        shootent = entity_hashes[index]
    else
        shootent = util.joaat(custom_egun_model)
    end
end)

entgungrav = false
menu.toggle(entity_gun, translations.entity_gun_gravity, {translations.entity_gun_gravity_cmd}, "", function(on)
    entgungrav = on
end)

saimbot_mode = "closest"
function get_aimbot_target()
    local dist = 1000000000
    local cur_tar = 0
    -- an aimbot should have immaculate response time so we shouldnt rely on the other entity pools for this data
    for k,v in pairs(entities.get_all_peds_as_handles()) do
        local target_this = true
        local player_pos = ENTITY.GET_ENTITY_COORDS(players.user_ped(), true)
        local ped_pos = ENTITY.GET_ENTITY_COORDS(v, true)
        local this_dist = MISC.GET_DISTANCE_BETWEEN_COORDS(player_pos['x'], player_pos['y'], player_pos['z'], ped_pos['x'], ped_pos['y'], ped_pos['z'], true)
        if players.user_ped() ~= v and not ENTITY.IS_ENTITY_DEAD(v) then
            if not satarget_players then
                if PED.IS_PED_A_PLAYER(v) then
                    target_this = false
                end
            end
            if not satarget_npcs then
                if not PED.IS_PED_A_PLAYER(v) then
                    target_this = false
                end
            end
            if not ENTITY.HAS_ENTITY_CLEAR_LOS_TO_ENTITY(players.user_ped(), v, 17) then
                target_this = false
            end
            if satarget_usefov then
                if not PED.IS_PED_FACING_PED(players.user_ped(), v, sa_fov) then
                    target_this = false
                end
            end
            if satarget_novehicles then
                if PED.IS_PED_IN_ANY_VEHICLE(v, true) then 
                    target_this = false
                end
            end
            if satarget_nogodmode then
                if not ENTITY._GET_ENTITY_CAN_BE_DAMAGED(v) then 
                    target_this = false 
                end
            end
            if not satarget_targetfriends and satarget_players then
                if PED.IS_PED_A_PLAYER(v) then
                    local pid = NETWORK.NETWORK_GET_PLAYER_INDEX_FROM_PED(v)
                    local hdl = pid_to_handle(pid)
                    if NETWORK.NETWORK_IS_FRIEND(hdl) then
                        target_this = false 
                    end
                end
            end
            if saimbot_mode == "closest" then
                if this_dist <= dist then
                    if target_this then
                        dist = this_dist
                        cur_tar = v
                    end
                end
            end 
        end
    end
    return cur_tar
end
sa_showtarget = true
satarget_usefov = true
menu.toggle_loop(silent_aimbotroot, translations.silent_aimbot, {translations.silent_aimbot_cmd}, translations.silent_aimbot_desc, function(toggle)
    local target = get_aimbot_target()
    if target ~= 0 then
        --local t_pos = ENTITY.GET_ENTITY_COORDS(target, true)
        local t_pos = PED.GET_PED_BONE_COORDS(target, 31086, 0.01, 0, 0)
        local t_pos2 = PED.GET_PED_BONE_COORDS(target, 31086, -0.01, 0, 0.00)
        if sa_showtarget then
            util.draw_ar_beacon(t_pos)
        end
        if PED.IS_PED_SHOOTING(players.user_ped()) then
            local wep = WEAPON.GET_SELECTED_PED_WEAPON(players.user_ped())
            local dmg = WEAPON.GET_WEAPON_DAMAGE(wep, 0)
            if satarget_damageo then
                dmg = sa_odmg
            end
            local veh = PED.GET_VEHICLE_PED_IS_IN(target, false)
            MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS_IGNORE_ENTITY(t_pos['x'], t_pos['y'], t_pos['z'], t_pos2['x'], t_pos2['y'], t_pos2['z'], dmg, true, wep, players.user_ped(), true, false, 10000, veh)
        end
    end
end)

menu.toggle(silent_aimbotroot, translations.silent_aimbot_players, {translations.silent_aimbot_players_cmd}, "", function(on)
    satarget_players = on
end)

menu.toggle(silent_aimbotroot, translations.silent_aimbot_npcs, {translations.silent_aimbot_npcs_cmd}, "", function(on)
    satarget_npcs = on
end)

menu.toggle(silent_aimbotroot, translations.use_fov, {translations.use_fov_cmd}, translations.use_fov_desc, function(on)
    satarget_usefov = on
end, true)

sa_fov = 60
menu.slider(silent_aimbotroot, translations.fov, {translations.fov_cmd}, "", 1, 270, 60, 1, function(s)
    sa_fov = s
end)

menu.toggle(silent_aimbotroot, translations.ignore_targets_inside_vehicles, {translations.ignore_targets_inside_vehicles.cmd}, translations.ignore_targets_inside_vehicles_desc, function(on)
    satarget_novehicles = on
end)

satarget_nogodmode = true
menu.toggle(silent_aimbotroot,  translations.ignore_godmoded_targets, {translations.ignore_godmoded_targets_cmd}, translations.ignore_godmoded_targets_desc, function(on)
    satarget_nogodmode = on
end, true)

menu.toggle(silent_aimbotroot, translations.target_friends, {translations.sa_target_friends_cmd}, "", function(on)
    satarget_targetfriends = on
end)

menu.toggle(silent_aimbotroot, translations.damage_override, {translations.damage_override_cmd}, "", function(on)
    satarget_damageo = on
end)

sa_odmg = 100
menu.slider(silent_aimbotroot, translations.damage_override_amount, {translations.damage_override_amount_cmd}, "", 1, 1000, 100, 1, function(s)
    sa_odmg = s
end)

menu.toggle(silent_aimbotroot, translations.display_target, {translations.display_target_cmd}, translations.display_target_desc, function(on)
    sa_showtarget = on
end, true)
--

local start_tint
local cur_tint
menu.toggle_loop(weapons_root, translations.rainbow_weapon_tint, {translations.rainbow_weapon_tint_cmd}, translations.rainbow_weapon_tint_desc, function()
    local plyr = players.user_ped()
    if start_tint == nil then
        start_tint = WEAPON.GET_PED_WEAPON_TINT_INDEX(plyr, WEAPON.GET_SELECTED_PED_WEAPON(plyr))
        cur_tint = start_tint
    end
    cur_tint = if cur_tint == 8 then 0 else cur_tint + 1
    WEAPON.SET_PED_WEAPON_TINT_INDEX(plyr,WEAPON.GET_SELECTED_PED_WEAPON(plyr), cur_tint)
    util.yield(50)
end, function()
        WEAPON.SET_PED_WEAPON_TINT_INDEX(players.user_ped(),WEAPON.GET_SELECTED_PED_WEAPON(players.user_ped()), start_tint)
        start_tint = nil
end)

menu.toggle(weapons_root, translations.invisible_weapons, {translations.invisible_weapons_cmd}, translations.invisible_weapons_desc, function(on)
    local plyr = players.user_ped()
    WEAPON.SET_PED_CURRENT_WEAPON_VISIBLE(plyr, not on, false, false, false) 
end)

aim_info = false
menu.toggle(weapons_root, translations.aim_info, {translations.aim_info_cmd}, translations.aim_info_desc, function(on)
    aim_info = on
end)

gun_stealer = false
menu.toggle(weapons_root, translations.car_stealer_gun, {translations.car_stealer_gun_cmd}, translations.car_stealer_gun_desc, function(on)
    gun_stealer = on
end)

paintball = false
menu.toggle(weapons_root, translations.paintball, {translations.paintball_cmd}, translations.paintball_desc, function(on)
    paintball = on
end)

drivergun = false
menu.toggle(weapons_root, translations.npc_driver_gun, {translations.npc_driver_gun_cmd}, translations.npc_driver_gun_desc, function(on)
    drivergun = on
end)

grapplegun = false
menu.toggle(weapons_root, translations.grapple_gun, {translations.grapple_gun_cmd}, translations.grapple_gun_desc, function(on)
    grapplegun = on
    if on then
        WEAPON.GIVE_WEAPON_TO_PED(players.user_ped(), util.joaat('weapon_pistol'), 9999, false, false)
        util.toast(translations.grapple_gun_active)
    end
end)


-- OBJECTS

objects_thread = util.create_thread(function (thr)
    local projectile_blips = {}
    while true do
        for k,b in pairs(projectile_blips) do
            if HUD.GET_BLIP_INFO_ID_ENTITY_INDEX(b) == 0 then 
                util.remove_blip(b) 
                projectile_blips[k] = nil
            end
        end
        if object_uses > 0 then
            if show_updates then
                ls_log("Object pool is being updated")
            end
            all_objects = entities.get_all_objects_as_handles()
            for k,obj in pairs(all_objects) do
                if reap then
                    request_control_of_entity(obj)
                end
                --- PROJECTILE SHIT
                if is_entity_a_projectile(ENTITY.GET_ENTITY_MODEL(obj)) then
                    if projectile_warn then
                        local c = ENTITY.GET_ENTITY_COORDS(obj)
                        local screen_c = world_to_screen_coords(c.x, c.y, c.z)
                        local color = to_rgb(255, 0, 0, 255)
                        --directx.draw_text(screen_c.x, screen_c.y, "!", 5, 0.100, color, false)
                        request_texture_dict_load('visualflow')
                        GRAPHICS.DRAW_SPRITE('visualflow', 'crosshair', screen_c.x, screen_c.y, 0.02, 0.03, 0.0, 255, 0, 0, 255, true, 0)
                    end
                    if projectile_cleanse then 
                        entities.delete(obj)
                    end
                    if projectile_spaz then
                        --local target = entity.get_entity_owner(obj) 
                        local strength = 20
                        ENTITY.APPLY_FORCE_TO_ENTITY(obj, 1, math.random(-strength, strength), math.random(-strength, strength), math.random(-strength, strength), 0.0, 0.0, 0.0, 1, true, false, true, true, true)
                    end
                    if slow_projectiles then
                        --ENTITY.SET_ENTITY_VELOCITY(obj, 0.0, 0.0, 0.0)
                        ENTITY.SET_ENTITY_MAX_SPEED(obj, 0.5)
                    end
                    if blip_projectiles then
                        if HUD.GET_BLIP_FROM_ENTITY(obj) == 0 then
                            local proj_blip = HUD.ADD_BLIP_FOR_ENTITY(obj)
                            HUD.SET_BLIP_SPRITE(proj_blip, 443)
                            HUD.SET_BLIP_COLOUR(proj_blip, 75)
                            projectile_blips[#projectile_blips + 1] = proj_blip 
                        end
                    end
                end
                --------------
                if l_e_o_on then
                    local size = get_model_size(ENTITY.GET_ENTITY_MODEL(obj))
                    if size.x > l_e_max_x or size.y > l_e_max_y or size.z > l_e_max_y then
                        entities.delete(obj)
                    end
                end
                if object_rainbow then
                    OBJECT._SET_OBJECT_LIGHT_COLOR(obj, 1, rgb[1], rgb[2], rgb[3])
                end

                if rapidtraffic then
                    ENTITY.SET_ENTITY_TRAFFICLIGHT_OVERRIDE(obj, tlightstate)
                end
            end    
        end
        util.yield()
    end
end)

-- PEDS

peds_thread = util.create_thread(function (thr)
    while true do
        if ped_uses > 0 then
            ls_log("Ped pool is being updated")
            all_peds = entities.get_all_peds_as_handles()
            for k,ped in pairs(all_peds) do
                if kill_aura then
                    if (kill_aura_peds and not PED.IS_PED_A_PLAYER(ped)) or (kill_aura_players and PED.IS_PED_A_PLAYER(ped)) then
                        local pid = NETWORK.NETWORK_GET_PLAYER_INDEX_FROM_PED(v)
                        local hdl = pid_to_handle(pid)
                        if (kill_aura_friends and not NETWORK.NETWORK_IS_FRIEND(hdl)) or not kill_aura_friends then
                            target = ENTITY.GET_ENTITY_COORDS(ped, false)
                            m_coords = ENTITY.GET_ENTITY_COORDS(players.user_ped(), false)
                            if MISC.GET_DISTANCE_BETWEEN_COORDS(m_coords.x, m_coords.y, m_coords.z, target.x, target.y, target.z, true) < kill_aura_dist and ENTITY.GET_ENTITY_HEALTH(ped) > 0 then
                                MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(target['x'], target['y'], target['z'], target['x'], target['y'], target['z']+0.1, 300.0, true, 100416529, players.user_ped(), true, false, 100.0)
                            end
                        end
                    end
                end
                if not PED.IS_PED_A_PLAYER(ped) then
                    if reap then
                        request_control_of_entity(ped)
                    end

                    if ped_no_ragdoll then 
                        PED.SET_PED_CAN_RAGDOLL(ped, false)
                    end

                    if ped_godmode then 
                        ENTITY.SET_ENTITY_INVINCIBLE(ped, true)
                    end

                    if hooker_esp then
                        local mdl = ENTITY.GET_ENTITY_MODEL(ped)
                        if PED.IS_PED_USING_SCENARIO(ped, "WORLD_HUMAN_PROSTITUTE_HIGH_CLASS") or PED.IS_PED_USING_SCENARIO(ped,"WORLD_HUMAN_PROSTITUTE_LOW_CLASS") then 
                            util.draw_ar_beacon(ENTITY.GET_ENTITY_COORDS(ped))
                        end
                    end

                    if ped_no_crits then
                        PED.SET_PED_SUFFERS_CRITICAL_HITS(ped, false)
                    end

                    if ped_highperception then
                        PED.SET_PED_HIGHLY_PERCEPTIVE(ped, true)
                        PED.SET_PED_HEARING_RANGE(ped, 1000.0)
                        PED.SET_PED_SEEING_RANGE(ped, 1000.0)
                        PED.SET_PED_VISUAL_FIELD_MIN_ANGLE(ped, 1000.0)
                    end

                    if ped_allcops then
                        PED.SET_PED_AS_COP(ped, true)
                    end

                    if ped_theflash then
                        PED.SET_PED_MOVE_RATE_OVERRIDE(ped, 10.0)
                    end

                    if rain_peds then 
                        if not ENTITY.IS_ENTITY_IN_AIR(ped) then 
                            local ped_c = ENTITY.GET_ENTITY_COORDS(players.user_ped())
                            ped_c.x = ped_c.x + math.random(-50, 50)
                            ped_c.y = ped_c.y + math.random(-50, 50)
                            ped_c.z = ped_c.z + math.random(50, 100)
                            ENTITY.SET_ENTITY_COORDS(ped, ped_c.x, ped_c.y, ped_c.z)
                            ENTITY.SET_ENTITY_VELOCITY(ped, 0.0, 0.0, -1.0)
                        end
                    end

                    if ped_hardened then
                        PED.SET_PED_COMBAT_ATTRIBUTES(ped, 5, true)
                        PED.SET_PED_FLEE_ATTRIBUTES(ped, 0, false)
                        PED.SET_PED_COMBAT_ATTRIBUTES(ped, 46, true)
                        PED.SET_PED_ACCURACY(ped, 100)
                        PED.SET_PED_COMBAT_ABILITY(ped, 3)
                    end

                    if peds_ignore then
                        if not PED.GET_PED_CONFIG_FLAG(ped, 17, true) then
                            PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(ped, true)
                            TASK.TASK_SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(ped, true)
                        end
                    end
                    if wantthesmoke then 
                        PED.SET_PED_AS_ENEMY(ped, true)
                        PED.SET_PED_COMBAT_ATTRIBUTES(ped, 5, true)
                        PED.SET_PED_FLEE_ATTRIBUTES(ped, 0, false)
                        PED.SET_PED_COMBAT_ATTRIBUTES(ped, 46, true)
                        TASK.TASK_COMBAT_PED(ped, players.user_ped(), 0, 16)
                    end
                    if roast_voicelines then
                        AUDIO.PLAY_PED_AMBIENT_SPEECH_NATIVE(ped, "GENERIC_INSULT_MED", "SPEECH_PARAMS_FORCE_SHOUTED")
                    end
    
                    if sex_voicelines then
                        AUDIO.PLAY_PED_AMBIENT_SPEECH_WITH_VOICE_NATIVE(ped, "SEX_GENERIC_FEM", "S_F_Y_HOOKER_01_WHITE_FULL_01", "SPEECH_PARAMS_FORCE_SHOUTED", 0)
                    end
    
                    if gluck_voicelines then
                        AUDIO.PLAY_PED_AMBIENT_SPEECH_WITH_VOICE_NATIVE(ped, "SEX_ORAL_FEM", "S_F_Y_HOOKER_01_WHITE_FULL_01", "SPEECH_PARAMS_FORCE_SHOUTED", 0)
                    end
    
                    if screamall then
                        AUDIO.PLAY_PAIN(ped, 7, 0)
                    end


                    if php_bars and get_distance_between_entities(players.user_ped(), ped) < 100.0 and
                    not PED.IS_PED_FATALLY_INJURED(ped) and ENTITY.IS_ENTITY_ON_SCREEN(ped) then
                        local headPos = PED.GET_PED_BONE_COORDS(ped, 0x322C --[[head]], 0.35, 0., 0.)
                        local perc = 0.0

                        if not PED.IS_PED_FATALLY_INJURED(ped) then
                            local maxHealth = PED.GET_PED_MAX_HEALTH(ped)
                            local health = ENTITY.GET_ENTITY_HEALTH(ped)
                            ---Peds die when their health is below the injured threshold
                            ---which is 100 by default, so we subtract it here so the perc is
                            ---zero when a ped dies.
                            perc = (health - 100.0) / (maxHealth - 100.0)
                            if perc > 1.0 then perc = 1.0  end
                        end
                        
                        local colour = get_health_colour(perc)
                        local scale = v3.new(0.10, 0.0, interpolate(0.0, 0.7, perc))
                        draw_marker(43, headPos, v3(), v3(), scale, false, colour, 0, 0)
                    end

                    if allpeds_gun ~= 0 then
                        WEAPON.GIVE_WEAPON_TO_PED(ped, allpeds_gun, 9999, false, false)
                    end

                    -- ONLINE INTERACTIONS
                    if aped_combat then
                        local tar = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(combat_tar)
                        if not PED.IS_PED_IN_COMBAT(ped, tar) then 
                            PED.SET_PED_COMBAT_ATTRIBUTES(ped, 5, true)
                            PED.SET_PED_FLEE_ATTRIBUTES(ped, 0, false)
                            PED.SET_PED_COMBAT_ATTRIBUTES(ped, 46, true)
                            TASK.TASK_COMBAT_PED(ped, combat_tar, 0, 16)
                        end
                    end


                end
            end
        end
        util.yield()
    end
end)

-- PEDS
ped_b_root = menu.list(peds_root, translations.ped_behavior, {translations.ped_behavior_cmd}, "")
ped_attributes_root = menu.list(peds_root, translations.ped_attributes, {translations.ped_attributes_cmd}, "")
ped_voice = menu.list(peds_root, translations.ped_voice, {translations.ped_voice_cmd}, "")
ped_spawn = menu.list(peds_root, translations.ped_spawn, {translations.ped_spawn_cmd}, "")

-- SPAWNING PEDS
num_peds_spawn = 1
function spawn_ped(hash)
    coords = ENTITY.GET_ENTITY_COORDS(players.user_ped(), false)
    coords.x = coords['x']
    coords.y = coords['y']
    coords.z = coords['z']
    local peds_spawned = {}
    request_model_load(hash)
    for i=1, num_peds_spawn do
        ped = entities.create_ped(28, hash, coords, math.random(0, 270))
        peds_spawned[#peds_spawned + 1] = ped
        if spawn_dancing then 
            local d = "anim@amb@nightclub_island@dancers@crowddance_facedj@hi_intensity"
            request_anim_dict(d)
            TASK.TASK_PLAY_ANIM(ped, d, "hi_dance_facedj_13_v2_male^5", 1.0, 1.0, -1, 3, 0.5, false, false, false)
            PED.SET_PED_KEEP_TASK(ped, true)
        end
        if is_pet then
            all_pets[#all_pets + 1] = ped
            ENTITY.SET_ENTITY_INVINCIBLE(ped, true)
            TASK.TASK_FOLLOW_TO_OFFSET_OF_ENTITY(ped, players.user_ped(), 0, -1, 0, 7.0, -1, 1, true)
            PED.SET_PED_COMBAT_ABILITY(ped, 3)
            PED.SET_PED_FLEE_ATTRIBUTES(ped, 0, false)
            PED.SET_PED_COMBAT_ATTRIBUTES(ped, 5, true)
            local blip = HUD.ADD_BLIP_FOR_ENTITY(ped)
            HUD.SET_BLIP_COLOUR(blip, 11)
        end
    end
    return peds_spawned
end

all_pets = {}
function spawn_pet(hash)
    request_model_load(hash)
    local c = ENTITY.GET_ENTITY_COORDS(players.user_ped(), false)
    local pet = entities.create_ped(28, hash, c, 0)
    all_pets[#all_pets + 1] = pet
    ENTITY.SET_ENTITY_INVINCIBLE(pet, true)
    PED.SET_PED_COMPONENT_VARIATION(pet, 0, 0, 2, 0)
    TASK.TASK_FOLLOW_TO_OFFSET_OF_ENTITY(pet, players.user_ped(), 0, -1, 0, 7.0, -1, 1, true)
    PED.SET_PED_COMBAT_ABILITY(pet, 0)
    PED.SET_PED_FLEE_ATTRIBUTES(pet, 0, true)
    PED.SET_PED_COMBAT_ATTRIBUTES(pet, 46, false)
    local blip = HUD.ADD_BLIP_FOR_ENTITY(pet)
    HUD.SET_BLIP_COLOUR(blip, 11)
end

local custom_animal = "a_c_retriever"
menu.text_input(ped_spawn, translations.custom_ped_input, {translations.custom_ped_input_cmd}, translations.custom_ped_input_desc, function(on_input)
    custom_animal = on_input
end, "a_c_retriever")


local animal_hashes = {1302784073, -1011537562, 802685111, util.joaat("a_c_chimp"), -1589092019, 1794449327, -664053099, -1920284487, util.joaat("a_c_retriever"), util.joaat('a_c_cow'), util.joaat("a_c_rabbit_01")}
local animal_options = {translations.lester, translations.rat, translations.fish, translations.chimp, translations.stingray, translations.hen, translations.deer, translations.killer_whale, translations.dog, translations.cow, translations.rabbit, translations.custom}
menu.list_action(ped_spawn, translations.spawn_ped, {translations.spawn_ped_cmd}, "", animal_options, function(index, value, click_type)
    if value == translations.custom then
        spawn_ped(util.joaat(custom_animal))
    else
        spawn_ped(animal_hashes[index])
    end
end)

menu.slider(ped_spawn, translations.spawn_count, {translations.spawn_count_cmd}, translations.spawn_count_desc, 1, 10, 1, 1, function(s)
    num_peds_spawn = s
end)


is_pet = false
menu.toggle(ped_spawn, translations.spawn_as_pet, {translations.spawn_as_pet_cmd}, translations.spawn_as_pet_desc, function(on)
    is_pet = on
end)

spawn_dancing = false
menu.toggle(ped_spawn, translations.spawn_dancing, {translations.spawn_dancing_cmd}, translations.spawn_dancing_desc, function(on)
    spawn_dancing = on
end)

allpeds_gun = 0
local gun_options = {translations.none, translations.pistol, translations.combat_pdw, translations.shotgun, translations.knife, translations.minigun}
menu.list_action(peds_root, translations.give_all_peds_gun, {translations.give_all_peds_gun_cmd}, "", gun_options, function(index, value, click_type)
    if index == 1 then
        allpeds_gun = 0
    else
        allpeds_gun = good_guns[index]
    end
end)

menu.action(peds_root, translations.teleport_all_to_me, {translations.teleport_all_to_me_cmd}, "", function(click_type)
    local c = ENTITY.GET_ENTITY_COORDS(players.user_ped(), false)
    all_peds = entities.get_all_peds_as_handles()
    for k,ped in pairs(all_peds) do
        if not PED.IS_PED_A_PLAYER(ped) then
            if PED.IS_PED_IN_ANY_VEHICLE(ped, true) then
                TASK.CLEAR_PED_TASKS_IMMEDIATELY(ped)
                TASK.TASK_LEAVE_ANY_VEHICLE(ped, 0, 16)
            end
            ENTITY.SET_ENTITY_COORDS(ped, c.x, c.y, c.z)
        end
    end
end)

rain_peds = false
menu.toggle(peds_root, translations.rain_peds, {translations.rain_peds_cmd}, "...", function(on)
    rain_peds = on
    mod_uses("ped", if on then 1 else -1)
end)

hooker_esp = false
menu.toggle(peds_root, translations.hooker_esp, {translations.hooker_esp_cmd}, "...", function(on)
    hooker_esp = on
    mod_uses("ped", if on then 1 else -1)
end)



function task_handler(type)
    -- whatever, just get it once this frame
    all_peds = entities.get_all_peds_as_handles()
    player_ped = PLAYER.PLAYER_PED_ID()
    for k,ped in pairs(all_peds) do
        if not PED.IS_PED_A_PLAYER(ped) then
            pluto_switch type do
                case "Flop":
                    TASK.TASK_SKY_DIVE(ped)
                    break
                case "Cover":
                    TASK.TASK_STAY_IN_COVER(ped)
                    break
                case "Writhe":
                    TASK.TASK_WRITHE(ped, player_ped, -1, 0)
                    break
                case "Vault":
                    TASK.TASK_CLIMB(ped, true)
                    break
                case "Cower":
                    TASK.TASK_COWER(ped, -1)
                    break
                case "Clear":
                    TASK.CLEAR_PED_TASKS(ped)
                    break
            end
        end
    end
end

ped_no_ragdoll = false
menu.toggle(ped_attributes_root, translations.no_ragdoll, {translations.no_ragdoll_cmd}, "", function(on)
    ped_no_ragdoll = on 
    mod_uses("ped", if on then 1 else -1)
end)

ped_godmode = false
menu.toggle(ped_attributes_root, translations.godmode_peds, {translations.godmode_peds_cmd}, "", function(on)
    ped_godmode = on 
    mod_uses("ped", if on then 1 else -1)
end)

ped_no_crits = false
menu.toggle(ped_attributes_root, translations.no_crits, {translations.no_crits_cmd}, "", function(on)
    ped_no_crits = on 
    mod_uses("ped", if on then 1 else -1)
end)

ped_highperception = false
menu.toggle(ped_attributes_root, translations.high_perception, {translations.high_perception_cmd}, translations.high_perception_desc, function(on)
    ped_highperception = on 
    mod_uses("ped", if on then 1 else -1)
end)

ped_allcops = false
menu.toggle(ped_attributes_root, translations.make_all_peds_cops, {translations.make_all_peds_cops_cmd}, "", function(on)
    ped_allcops = on 
    mod_uses("ped", if on then 1 else -1)
end)

ped_theflash = false
menu.toggle(ped_attributes_root, translations.looney_tunes, {translations.looney_tunes_cmd}, translations.looney_tunes_cmd, function(on)
    ped_theflash = on 
    mod_uses("ped", if on then 1 else -1)
end)

ped_hardened = false
menu.toggle(ped_attributes_root, translations.hardened, {translations.hardened_cmd}, translations.hardened_desc, function(on)
    ped_hardened = on 
    mod_uses("ped", if on then 1 else -1)
end)



local task_dict = {"flop", "cover", "vault"}
local task_options = {translations.flop, translations.cover, translations.vault, translations.cower, translations.writhe, translations.clear}
menu.list_action(peds_root, translations.task_all, {translations.task_all_cmd}, "", task_options, function(index, value, click_type)
    task_handler(value)
end)

php_bars = false
menu.toggle(peds_root, translations.ped_hp_bars, {translations.ped_hp_bars_cmd}, translations.ped_hp_bars_desc, function(on)
    php_bars = on
    mod_uses("ped", if on then 1 else -1)
    if vhp_bars and on then
        util.toast(translations.ped_hp_bars_warning)
    end
end)

peds_ignore = false
menu.toggle(ped_b_root, translations.oblivious_peds, {translations.oblivious_peds_cmd}, translations.oblivious_peds_desc, function(on)
    peds_ignore = on
    mod_uses("ped", if on then 1 else -1)
end)

wantthesmoke = false
menu.toggle(ped_b_root, translations.peds_attack_me, {translations.peds_attack_me_cmd}, translations.peds_attack_me_desc, function(on)
    wantthesmoke = on
    mod_uses("ped", if on then 1 else -1)
end)

make_peds_cops = false
menu.toggle(ped_b_root, translations.make_nearby_peds_cops, {translations.make_nearby_peds_cops_cmd}, translations.make_nearby_peds_cops_desc, function(on)
    make_peds_cops = on
    mod_uses("ped", if on then 1 else -1)
end)

menu.toggle(ped_b_root, translations.detroit, {translations.detroit_cmd}, translations.detroit_desc, function(on)
    MISC.SET_RIOT_MODE_ENABLED(on)
end)

roast_voicelines = false
menu.toggle(ped_voice, translations.roast_voicelines, {translations.roast_voicelines_cmd}, translations.roast_voicelines_desc, function(on)
    roast_voicelines = on
    mod_uses("ped", if on then 1 else -1)
end)

sex_voicelines = false
menu.toggle(ped_voice, translations.sex_voicelines, {translations.sex_voicelines_cmd}, translations.sex_voicelines_desc, function(on)
    sex_voicelines = on
    mod_uses("ped", if on then 1 else -1)
end)

gluck_voicelines = false
menu.toggle(ped_voice, translations.gluck_gluck_9000_voicelines, {translations.gluck_gluck_9000_voicelines_cmd}, translations.gluck_gluck_9000_voicelines_desc, function(on)
    gluck_voicelines = on
    mod_uses("ped", if on then 1 else -1)
end)

screamall = false
menu.toggle(ped_voice, translations.scream, {translations.scream_cmd}, translations.scream_desc, function(on)
    screamall = on
    mod_uses("ped", if on then 1 else -1)
end)

-- VEHICLES

v_phys_root = menu.list(vehicles_root, translations.vehicle_physics, {translations.vehicle_physics_cmd}, translations.vehicle_physics_desc)
vc_root = menu.list(v_phys_root, translations.vehicle_chaos, {translations.vehicle_chaos_root_cmd}, translations.vehicle_chaos_desc)
v_traffic_root = menu.list(vehicles_root, translations.vehicle_traffic, {translations.vehicle_traffic_cmd}, translations.vehicle_traffic_desc)

function get_closest_vehicle(entity)
    local coords = ENTITY.GET_ENTITY_COORDS(entity, true)
    local vehicles = entities.get_all_vehicles_as_handles()
    -- init this at some ridiculously large number we will never reach, ez
    local closestdist = 1000000
    local closestveh = 0
    for k, veh in pairs(vehicles) do
        if veh ~= PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), false) then
            local vehcoord = ENTITY.GET_ENTITY_COORDS(veh, true)
            local dist = MISC.GET_DISTANCE_BETWEEN_COORDS(coords['x'], coords['y'], coords['z'], vehcoord['x'], vehcoord['y'], vehcoord['z'], true)
            if dist < closestdist then
                closestdist = dist
                closestveh = veh
            end
        end
    end
    return closestveh
end

menu.action(vehicles_root, translations.teleport_into_closest_vehicle, {translations.teleport_into_closest_vehicle_cmd}, translations.teleport_into_closest_vehicle_desc, function(on_click)
    local closestveh = get_closest_vehicle(players.user_ped())
    local driver = VEHICLE.GET_PED_IN_VEHICLE_SEAT(closestveh, -1)
    if VEHICLE.IS_VEHICLE_SEAT_FREE(closestveh, -1) then
        PED.SET_PED_INTO_VEHICLE(players.user_ped(), closestveh, -1)
    else
        if not PED.IS_PED_A_PLAYER(driver) then
            entities.delete(driver)
            PED.SET_PED_INTO_VEHICLE(players.user_ped(), closestveh, -1)
        elseif VEHICLE.ARE_ANY_VEHICLE_SEATS_FREE(closestveh) then
            for i=0, 10 do
                if VEHICLE.IS_VEHICLE_SEAT_FREE(closestveh, i) then
                    PED.SET_PED_INTO_VEHICLE(players.user_ped(), closestveh, i)
                end
            end
        else
            util.toast(translations.teleport_into_closest_vehicle_error)
        end
    end
end)

vehicle_chaos = false
menu.toggle(vc_root, translations.vehicle_chaos, {translations.vehicle_chaos_cmd}, translations.vehicle_chaos_desc, function(on)
    vehicle_chaos = on
    mod_uses("vehicle", if on then 1 else -1)
end)

vc_gravity = true
menu.toggle(vc_root, translations.vehicle_chaos_gravity, {translations.vehicle_chaos_gravity_cmd}, translations.vehicle_chaos_gravity_desc, function(on)
    vc_gravity = on
end, true)

vc_speed = 100
menu.slider(vc_root, translations.vehicle_chaos_speed, {translations.vehicle_chaos_speed_cmd}, translations.vehicle_chaos_speed_desc, 30, 300, 100, 10, function(s)
  vc_speed = s
end)

vhp_bars = false
menu.toggle(vehicles_root, translations.vehicle_hp_bars, {translations.vehicle_hp_bars_cmd}, translations.vehicle_hp_bars_cmd, function(on)
    vhp_bars = on
    mod_uses("vehicle", if on then 1 else -1)
    if php_bars and on then
        util.toast(translations.vehicle_hp_bars_warn)
    end
end)

ascend_vehicles = false
menu.toggle(v_phys_root, translations.ascend_all_nearby_vehicles, {translations.ascend_all_nearby_vehicles_cmd}, translations.ascend_all_nearby_vehicles_desc, function(on)
    ascend_vehicles = on
    mod_uses("vehicle", if on then 1 else -1)
end)

rain_vehicles = false
menu.toggle(v_phys_root, translations.rain_vehicles, {translations.rain_vehicles_cmd}, translations.rain_vehicles_desc, function(on)
    rain_vehicles = on
    mod_uses("vehicle", if on then 1 else -1)
end)

inferno = false
menu.toggle(v_phys_root, translations.inferno, {translations.inferno_cmd}, translations.inferno_desc, function(on)
    inferno = on
    mod_uses("vehicle", if on then 1 else -1)
end, false)

blackhole = false
menu.toggle(v_phys_root, translations.vehicle_blackhole, {translations.vehicle_blackhole_cmd}, translations.vehicle_blackhole_desc, function(on)
    blackhole = on
    mod_uses("vehicle", if on then 1 else -1)
    if on then
        holecoords = ENTITY.GET_ENTITY_COORDS(players.user_ped(), true)
        util.toast(translations.vehicle_blackhole_reposition)
    end
end)

hole_zoff = 50
menu.slider(v_phys_root, translations.blackhole_z_offset, {translations.blackhole_z_offset_cmd}, translations.blackhole_z_offset_desc, 0, 100, 50, 10, function(s)
    hole_zoff = s
  end)

beep_cars = false
menu.toggle(vehicles_root, translations.infinite_horn_on_all_nearby_vehicles, {translations.infinite_horn_on_all_nearby_vehicles_cmd}, translations.infinite_horn_on_all_nearby_vehicles_desc, function(on)
    beep_cars = on
    mod_uses("vehicle", if on then 1 else -1)
end)

halt_traffic = false
menu.toggle(v_traffic_root, translations.halt_traffic, {translations.halt_traffic_cmd}, translations.halt_traffic_desc, function(on)
    halt_traffic = on
    mod_uses("vehicle", if on then 1 else -1)
end)

reverse_traffic = false
menu.toggle(v_traffic_root, translations.reverse_traffic, {translations.reverse_traffic_cmd}, "", function(on)
    reverse_traffic = on
    mod_uses("vehicle", if on then 1 else -1)
end)

---Nowiry: This thread is causing a huge fps drop, around 30% in my machine (not matter the option you enable),
---Getting the driver of every single vehicle on tick seems to be the problem
vehicles_thread = util.create_thread(function (thr)
    while true do
        if vehicle_uses > 0 then
            ls_log("Vehicle pool is being updated")
            all_vehicles = entities.get_all_vehicles_as_handles()
            for k,veh in pairs(all_vehicles) do
                if l_e_v_on then
                    local size = get_model_size(ENTITY.GET_ENTITY_MODEL(veh))
                    if size.x > l_e_max_x or size.y > l_e_max_y or size.z > l_e_max_y then
                        entities.delete(veh)
                    end
                end

                ---Also making sure the vehicle is on screen and nearby the user ped, the idea is not to
                ---draw unnecessary markers and prevent a significant fps drop (as experienced)
                if vhp_bars and get_distance_between_entities(players.user_ped(), veh) < 200.0 and
                not ENTITY.IS_ENTITY_DEAD(veh, false) and ENTITY.IS_ENTITY_ON_SCREEN(veh) then
                    local modelHash = ENTITY.GET_ENTITY_MODEL(veh)
                    local min, max = v3.new(), v3.new()
                    MISC.GET_MODEL_DIMENSIONS(modelHash, min, max)
                    local pos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(veh, 0.0, 0.0, max.z + 0.3)
                    local perc = 0.0

                    if not ENTITY.IS_ENTITY_DEAD(veh, false) then
                        local maxHealth = ENTITY.GET_ENTITY_MAX_HEALTH(veh)
                        local health = ENTITY.GET_ENTITY_HEALTH(veh)
                        perc = health / maxHealth
                        if perc > 1.0 then perc = 1.0  end
                    end
                    
                    local colour = get_health_colour(perc)
                    local scale = v3.new(0.10, 0.0, interpolate(0.0, 0.7, perc))
                    draw_marker(43, pos, v3(), v3(), scale, false, colour, 0, 0)
                end

                local driver = VEHICLE.GET_PED_IN_VEHICLE_SEAT(veh, -1)
                -- FOR THINGS THAT SHOULD NOT WORK ON CARS WITH PLAYERS DRIVING THEM
                if player_cur_car ~= veh and not (PED.IS_PED_A_PLAYER(driver) or driver == 0) then
                    
                    ---You're stopping the execution of this thread for five seconds or maybe less if you got control of the vehicle,
                    ---for every vehicle, on tick! Intead you should use a non-loop-based control request like request_control_once
                    if reap then
                        request_control_of_entity(veh)
                    end
                    if inferno then
                        local coords = ENTITY.GET_ENTITY_COORDS(veh, true)
                        FIRE.ADD_EXPLOSION(coords['x'], coords['y'], coords['z'], 7, 100.0, true, false, 1.0)
                    end

                    if beep_cars then
                        if not AUDIO.IS_HORN_ACTIVE(veh) then
                            VEHICLE.START_VEHICLE_HORN(veh, 200, util.joaat("HELDDOWN"), true)
                        end
                    end

                    if blackhole then
                        if bh_target ~= -1 then
                            holecoords = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(bh_target), true)
                        end
                        vcoords = ENTITY.GET_ENTITY_COORDS(veh, true)
                        speed = 100
                        local x_vec = (holecoords['x']-vcoords['x'])*speed
                        local y_vec = (holecoords['y']-vcoords['y'])*speed
                        local z_vec = ((holecoords['z']+hole_zoff)-vcoords['z'])*speed
                        -- dumpster fire if this goes wrong lol
                        ENTITY.SET_ENTITY_INVINCIBLE(veh, true)
                        --losioVEHICLE.SET_VEHICLE_GRAVITY(veh, false)
                        ENTITY.APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(veh, 1, x_vec, y_vec, z_vec, true, false, true, true)
                    end

                    if vehicle_chaos then
                        VEHICLE.SET_VEHICLE_OUT_OF_CONTROL(veh, false, true)
                        VEHICLE.SET_VEHICLE_FORWARD_SPEED(veh, vc_speed)
                        VEHICLE.SET_VEHICLE_GRAVITY(veh, vc_gravity)
                    end
                
                    if halt_traffic then
                        VEHICLE.BRING_VEHICLE_TO_HALT(veh, 0.0, -1, true)
                        coords = ENTITY.GET_ENTITY_COORDS(veh, false)
                    end

                    if ascend_vehicles then
                        VEHICLE.SET_VEHICLE_UNDRIVEABLE(veh, true)
                        VEHICLE.SET_VEHICLE_GRAVITY(veh, false)
                        ENTITY.APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(veh, 4, 5.0, 0.0, 0.0, true, true, true, true)
                    end

                    if rain_vehicles then 
                        if not ENTITY.IS_ENTITY_IN_AIR(veh) then 
                            local ped_c = ENTITY.GET_ENTITY_COORDS(players.user_ped())
                            ped_c.x = ped_c.x + math.random(-50, 50)
                            ped_c.y = ped_c.y + math.random(-50, 50)
                            ped_c.z = ped_c.z + math.random(100, 120)
                            ENTITY.SET_ENTITY_COORDS(veh, ped_c.x, ped_c.y, ped_c.z)
                        end
                    end

                    if reverse_traffic then
                        ped = VEHICLE.GET_PED_IN_VEHICLE_SEAT(veh, -1)
                        TASK.TASK_VEHICLE_TEMP_ACTION(ped, veh, 3, -1)
                    end
                end
            end
        end
        util.yield()
    end
end)


-- PICKUPS

pickups_thread = util.create_thread(function(thr)
    while true do
        if pickup_uses > 0 then
            ls_log("Pickups pool is being updated")
            all_pickups = entities.get_all_pickups_as_handles()
            for k,p in pairs(all_pickups) do
                if reap then
                    request_control_of_entity(p)
                end

                if tp_all_pickups then
                    local pos = ENTITY.GET_ENTITY_COORDS(tp_pickup_tar, true)
                    ENTITY.SET_ENTITY_COORDS_NO_OFFSET(p, pos['x'], pos['y'], pos['z'], true, false, false)
                end
            end
        end
        util.yield()
    end
end)

tp_all_pickups = false
tp_pickup_tar = players.user_ped()
menu.toggle(pickups_root, translations.teleport_all_pickups, {translations.teleport_all_pickups_cmd}, translations.teleport_all_pickups_desc, function(on)
    tp_all_pickups = on
    mod_uses("pickup", if on then 1 else -1)
end)

-- WORLD
protected_areas_root = menu.list(world_root, translations.protected_areas, {translations.protected_areas_cmd}, translations.protected_areas_desc)
projectiles_root = menu.list(world_root, translations.projectiles, {translations.projectiles_cmd}, "")
entity_limits_root = menu.list(protections_root, translations.entity_limits, {translations.entity_limits_cmd}, translations.entity_limits_desc)
active_protected_areas_root = menu.list(protected_areas_root, translations.active_areas, {translations.active_areas_cmd},  translations.active_areas_desc)

projectile_warn = false
menu.toggle(projectiles_root, translations.draw_warning, {translations.draw_warning_cmd}, translations.draw_warning_desc, function(on)
    projectile_warn = on
    mod_uses("object", if on then 1 else -1)
end)

projectile_cleanse = false
menu.toggle(projectiles_root, translations.delete_projectiles, {translations.delete_projectiles_cmd}, translations.delete_projectiles_desc, function(on)
    projectile_cleanse = on
    mod_uses("object", if on then 1 else -1)
end)

projectile_spaz = false
menu.toggle(projectiles_root, translations.projectile_spaz, {translations.projectile_spaz_cmd}, translations.projectile_spaz_desc, function(on)
    projectile_spaz = on
    mod_uses("object", if on then 1 else -1)
end)

slow_projectiles = false
menu.toggle(projectiles_root, translations.extremely_slow_projectiles, {translations.extremely_slow_projectiles_cmd}, "", function(on)
    slow_projectiles = on
    mod_uses("object", if on then 1 else -1)
end)

blip_projectiles = false
menu.toggle(projectiles_root, translations.blips_for_projectiles, {translations.blips_for_projectiles_cmd  }, "", function(on)
    blip_projectiles = on
    mod_uses("object", if on then 1 else -1)
end)

function get_closest_projectile()
    local closest = 100000000000
    local closest_obj = 0
    for k,obj in pairs(entities.get_all_objects_as_handles()) do 
        if is_entity_a_projectile(ENTITY.GET_ENTITY_MODEL(obj)) then
            local c = ENTITY.GET_ENTITY_COORDS(obj) 
            local c2 = ENTITY.GET_ENTITY_COORDS(players.user_ped())
            local d = MISC.GET_DISTANCE_BETWEEN_COORDS(c.x, c.y, c.z, c2.x, c2.y, c2.z, true)
            if d < closest then
                closest_obj = obj
                closest = d
            end 
        end
    end
    return closest_obj
end

menu.action(projectiles_root, translations.ride_closest_projectile, {translations.ride_closest_projectile_cmd}, ".", function(on)
    closest_obj = get_closest_projectile()
    if closest_obj ~= 0 then 
        util.toast(translations.ride_closest_projectile_warn)
        ENTITY.ATTACH_ENTITY_TO_ENTITY(players.user_ped(), closest_obj, 0, 0.0, -0.20, 2.00, 1.0, 1.0,1, true, true, true, false, 0, true)
    end
end)


l_e_v_on = false
l_e_o_on = false
menu.toggle(entity_limits_root, translations.delete_large_vehicles, {translations.delete_large_vehicles_cmd}, "", function(on)
    mod_uses("vehicle", if on then 1 else -1)
    l_e_v_on = true
end)

menu.toggle(entity_limits_root, translations.delete_large_objects, {translations.delete_large_objects_cmd}, "", function(on)
    mod_uses("object", if on then 1 else -1)
    l_e_o_on = true
end)

l_e_max_x = 50
l_e_max_y = 50
l_e_max_z = 50
menu.slider(entity_limits_root, translations.max_x_size, {translations.max_x_size_cmd}, translations.max_x_size_desc, 1, 10000, 50, 1, function(s)
    l_e_max_x = s
end)

menu.slider(entity_limits_root, translations.max_y_size, {translations.max_y_size_cmd}, translations.max_y_size_desc, 1, 10000, 50, 1, function(s)
    l_e_max_y = s
end)

menu.slider(entity_limits_root, translations.max_z_size, {translations.max_z_size_cmd}, translations.max_z_size_desc, 1, 10000, 50, 1, function(s)
    l_e_max_z = s
end)



protected_area_radius = 100
protected_areas = {}
protected_area_allow_friends = true
protected_areas_on = false

menu.toggle(protected_areas_root, translations.enforce_areas, {translations.enforce_areas_cmd}, translations.enforce_areas_desc, function(on)
    mod_uses("player", if on then 1 else -1)
    protected_areas_on = on
end)


menu.slider(protected_areas_root, translations.area_radius, {translations.area_radius_cmd}, translations.area_radius_desc, 10, 1000, 100, 10, function(s)
    protected_area_radius = s
end)

menu.toggle(protected_areas_root, translations.always_allow_friends, {translations.always_allow_friends_cmd}, translations.always_allow_friends_desc, function(on)
    protected_area_allow_friends = on
end, true)


menu.toggle(protected_areas_root, translations.kill_only_armed_players, {translations.kill_only_armed_players_cmd}, translations.kill_only_armed_players_desc, function(on)
    protected_area_kill_armed = on
end)


-- -1569615261

menu.action(protected_areas_root, translations.define_protected_area, {translations.define_protected_area_cmd}, translations.define_protected_area_desc, function(click_type)
    local c = ENTITY.GET_ENTITY_COORDS(players.user_ped(), false)
    blip = HUD.ADD_BLIP_FOR_RADIUS(c.x, c.y, c.z, protected_area_radius)
    HUD.SET_BLIP_COLOUR(blip, 61)
    HUD.SET_BLIP_ALPHA(blip, 128)
    local this_area = {}
    this_area.blip = blip
    this_area.x = c.x
    this_area.y = c.y
    this_area.z = c.z
    this_area.radius = protected_area_radius
    pa_next = #protected_areas + 1
    protected_areas[pa_next] = this_area
    local new_protected_area = menu.list(active_protected_areas_root, tostring(pa_next), {translations.protectedarea_cmd .. pa_next}, translations.protectedarea_desc)
    menu.action(new_protected_area, translations.delete, {translations.delete_pa_cmd .. tostring(pa_next)}, translations.delete_pa_desc, function(click_type)
        util.remove_blip(blip)
        protected_areas[pa_next] = nil
        menu.delete(new_protected_area)
        util.toast(translations.pa_deleted)
    end)
end)


supercleanse = menu.action(world_root, translations.super_cleanse, {translations.super_cleanse_cmd}, translations.super_cleanse_desc, function(click_type)
    menu.show_warning(supercleanse, click_type, translations.super_cleanse_warn, function()
        local ct = 0
        for k,ent in pairs(entities.get_all_vehicles_as_handles()) do
            entities.delete(ent)
            ct = ct + 1
        end
        for k,ent in pairs(entities.get_all_peds_as_handles()) do
            if not PED.IS_PED_A_PLAYER(ent) then
                entities.delete(ent)
            end
            ct = ct + 1
        end
        for k,ent in pairs(entities.get_all_objects_as_handles()) do
            entities.delete(ent)
            ct = ct + 1
        end
        util.toast(translations.super_cleanse_complete .. ct .. translations.entities_removed)
    end, function(l)
    end, true)
end)

island_block = 0
menu.action(world_root, translations.sky_island, {translations.sky_island_cmd}, translations.sky_island_desc, function(click_type)
    local c = {}
    c.x = 0
    c.y = 0
    c.z = 500
    PED.SET_PED_COORDS_KEEP_VEHICLE(players.user_ped(), c.x, c.y, c.z+5)
    if island_block == 0 or not ENTITY.DOES_ENTITY_EXIST(island_block) then
        request_model_load(1054678467)
        island_block = entities.create_object(1054678467, c)
    end
end)

object_rainbow = false
menu.toggle(world_root, translations.rainbow_object_lights, {translations.rainbow_object_lights_cmd}, translations.rainbow_object_lights_desc, function(on)
    object_rainbow = on
    mod_uses("object", if on then 1 else -1)
end)

rapidtraffic = false
menu.toggle(world_root, translations.rapid_traffic_lights, {translations.rapid_traffic_lights_cmd}, translations.rapid_traffic_lights_desc, function(on)
    rapidtraffic = on
    mod_uses("object", if on then 1 else -1)
end)

local angry_planes = false
local angry_planes_tar = 0
function start_angryplanes_thread()
    util.create_thread(function()
        local v_hashes = {util.joaat('lazer'), util.joaat('jet'), util.joaat('cargoplane'), util.joaat('titan'), util.joaat('luxor'), util.joaat('seabreeze'), util.joaat('vestra'), util.joaat('volatol'), util.joaat('tula'), util.joaat('buzzard'), util.joaat('avenger')}
        if angry_planes_tar == 0 then 
            angry_planes_tar = players.user_ped()
        end
        while true do
            if not angry_planes then 
                util.stop_thread()
            end
            local p_hash = util.joaat('s_m_m_pilot_01')
            local radius = 200
            local c = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(angry_planes_tar, math.random(-radius, radius), math.random(-radius, radius), math.random(600, 800))
            local pick = v_hashes[math.random(1, #v_hashes)]
            request_model_load(pick)
            local aircraft = entities.create_vehicle(pick, c, math.random(0, 270))
            set_entity_face_entity(aircraft, angry_planes_tar, true)
            VEHICLE.SET_VEHICLE_ENGINE_ON(aircraft, true, true, false)
            VEHICLE.SET_HELI_BLADES_FULL_SPEED(aircraft)
            VEHICLE.SET_VEHICLE_FORWARD_SPEED(aircraft, VEHICLE.GET_VEHICLE_ESTIMATED_MAX_SPEED(aircraft)+1000.0)
            VEHICLE.SET_VEHICLE_OUT_OF_CONTROL(aircraft, true, true)
            --local blip = HUD.ADD_BLIP_FOR_ENTITY(aircraft)
            --HUD.SET_BLIP_SPRITE(blip, 90)
            --HUD.SET_BLIP_COLOUR(blip, 75)
            util.yield(5000)
        end
    end)
end

menu.toggle(world_root, translations.angry_planes, {translations.angry_planes_cmd}, translations.angry_planes_desc, function(on)
    angry_planes = on
    start_angryplanes_thread()
end)


-- TWEAKS
fakemessages_root = menu.list(tweaks_root, translations.fake_alerts, {translations.fake_alerts_cmd}, translations.fake_alerts_desc)

menu.action(tweaks_root, translations.force_cutscene, {translations.force_cutscene_cmd}, translations.force_cutscene_desc, function(click_type)
    util.toast(translations.type_cutscene_name)
    menu.show_command_box(translations.force_cutscene_cmd .. " ")
end, function(on_command)
    CUTSCENE.REQUEST_CUTSCENE(on_command, 8)
    local st = os.time()
    local s = false
    while true do
        if CUTSCENE.HAS_CUTSCENE_LOADED() then
            s = true
            break
        else
            if os.time() - st >= 10 then
                util.toast(translations.cutscene_fail)
                s = false
                return
            end
        end
        util.yield()
    end
    if s then
        CUTSCENE.START_CUTSCENE(0)
    end
end)


menu.toggle(tweaks_root, translations.music_only_radio, {translations.music_only_radio_cmd}, translations.music_only_radio_desc, function(on)
    num_unlocked = AUDIO.GET_NUM_UNLOCKED_RADIO_STATIONS()
    if on then
        for i=1, num_unlocked do
            AUDIO.SET_RADIO_STATION_MUSIC_ONLY(AUDIO.GET_RADIO_STATION_NAME(i), true)
        end
    else
        for i=1, num_unlocked do
            AUDIO.SET_RADIO_STATION_MUSIC_ONLY(AUDIO.GET_RADIO_STATION_NAME(i), false)
        end
    end
end)

menu.toggle(tweaks_root, translations.lock_minimap_angle, {translations.lock_minimap_angle_cmd}, translations.lock_minimap_angle_desc, function(on)
    if on then
        HUD.LOCK_MINIMAP_ANGLE(0)
    else
        HUD.UNLOCK_MINIMAP_ANGLE()
    end
end)

hud_rgb_index = 1
hud_rgb_colors = {6, 18, 9}
menu.toggle_loop(tweaks_root, translations.party_mode, {translations.party_mode_cmd}, translations.party_mode_desc, function(on)
    HUD.FLASH_MINIMAP_DISPLAY_WITH_COLOR(hud_rgb_colors[hud_rgb_index])
    hud_rgb_index = hud_rgb_index + 1
    if hud_rgb_index == 4 then
        hud_rgb_index = 1
    end
    util.yield(200)
end)

--FLASH_MINIMAP_DISPLAY_WITH_COLOR(int hudColorIndex)


--LOCK_MINIMAP_ANGLE(int angle)

function alert_thuds()
    util.create_thread(function()
        AUDIO.PLAY_SOUND_FRONTEND(-1, "Hit_In", "PLAYER_SWITCH_CUSTOM_SOUNDSET")
        util.yield(500)
        AUDIO.PLAY_SOUND_FRONTEND(-1, "Hit_In", "PLAYER_SWITCH_CUSTOM_SOUNDSET")
        util.yield(500)
        AUDIO.PLAY_SOUND_FRONTEND(-1, "Hit_In", "PLAYER_SWITCH_CUSTOM_SOUNDSET")
    end)
end

fake_alert_delay = 0
function show_custom_alert_until_enter(l1)
    util.yield(fake_alert_delay)
    alert_thuds()
    poptime = os.time()
    while true do
        if PAD.IS_CONTROL_JUST_RELEASED(18, 18) then
            if os.time() - poptime > 0.1 then
                break
            end
        end
        native_invoker.begin_call()
        native_invoker.push_arg_string("ALERT")
        native_invoker.push_arg_string("JL_INVITE_ND")
        native_invoker.push_arg_int(2)
        native_invoker.push_arg_string("")
        native_invoker.push_arg_bool(true)
        native_invoker.push_arg_int(-1)
        native_invoker.push_arg_int(-1)
        -- line here
        native_invoker.push_arg_string(l1)
        -- optional second line here
        native_invoker.push_arg_int(0)
        native_invoker.push_arg_bool(true)
        native_invoker.push_arg_int(0)
        native_invoker.end_call("701919482C74B5AB")
        util.yield()
    end
end


menu.slider(fakemessages_root, translations.alert_delay, {translations.alert_delay_cmd}, translations.alert_delay_desc, 0, 300, 0, 1, function(s)
    fake_alert_delay = s*1000
end)

local fake_suspend_date = translations.initial_suspension_date
menu.text_input(fakemessages_root, translations.custom_suspension_date, {translations.custom_suspension_date_cmd}, translations.custom_suspension_date_desc, function(on_input)
    fake_suspend_date = on_input
end, "July 15, 2000")

local custom_alert = translations.initial_custom_alert
menu.text_input(fakemessages_root, translations.custom_alert_text, {translations.custom_alert_text_cmd}, translations.custom_alert_text_desc, function(on_input)
    custom_alert = on_input
end, "hello world")


alert_options = {translations.fake_alert_1, translations.fake_alert_2, translations.fake_alert_3, translations.fake_alert_4, translations.fake_alert_5, translations.custom}
menu.list_action(fakemessages_root, translations.fake_alert, {translations.fake_alert_cmd}, "", alert_options, function(index, value, click_type)
    pluto_switch index do 
        case 1: 
            show_custom_alert_until_enter(translations.fake_alert_1_ct)
            break 
        case 2:
            show_custom_alert_until_enter(translations.fake_alert_2_ct)
            break
        case 3:
            show_custom_alert_until_enter(translations.fake_alert_3_ct)
            break
        case 4:
            show_custom_alert_until_enter(translations.fake_alert_4_ct)
            break
        case 5:
            show_custom_alert_until_enter(translations.fake_alert_5_ct_1 .. fake_suspend_date .. translations.fake_alert_5_ct_2)
            break
        case 6:
            show_custom_alert_until_enter(custom_alert)
            break
    end
end)

-- PLAYERS AND TROLLING

function get_best_mug_target()
    local most = 0
    local mostp = 0
    for k,p in pairs(players.list(true, true, true)) do
        cur_wallet = players.get_wallet(p)
        if cur_wallet > most then
            most = cur_wallet
            mostp = p
        end
    end
    if cur_wallet == nil then
        util.toast(translations.best_mug_alone)
        return
    end
    if most ~= 0 then
        return PLAYER.GET_PLAYER_NAME(mostp) .. translations.best_mug_1 .. most .. translations.best_mug_2
    else
        util.toast(translations.best_mug_fail)
        return nil
    end
end

function get_poorest_player()
    local least = 10000000000000000
    local leastp = 0
    for k,p in pairs(players.list(true, true, true)) do
        cur_assets = players.get_wallet(p) + players.get_bank(p)
        if cur_assets < least then
            least = cur_assets
            leastp = p
        end
    end
    if cur_assets == nil then
        util.toast(translations.poorest_alone)
        return
    end
    if least ~= 10000000000000000 then
        return PLAYER.GET_PLAYER_NAME(leastp) .. translations.poorest_1 .. players.get_wallet(leastp) .. translations.poorest_2 .. players.get_bank(leastp) .. translations.poorest_3
    else
        util.toast()
        return nil
    end
end

function get_richest_player()
    local most = 0
    local mostp = 0
    for k,p in pairs(players.list(false, true, true)) do
        cur_assets = players.get_wallet(p) + players.get_bank(p)
        if cur_assets > most then
            most = cur_assets
            mostp = p
        end
    end
    if cur_assets == nil then
        util.toast(translations.richest_alone)
        return
    end
    if most ~= 0 then
        return PLAYER.GET_PLAYER_NAME(mostp) .. translations.richest_1 .. players.get_wallet(mostp) .. translations.richest_2 .. players.get_bank(mostp) .. translations.richest_3
    else
        util.toast(translations.richest_fail)
        return nil
    end
end

function get_horniest_player()
    local highest_horniness = 0
    local horniest = 0
    local most_lapdances = 0
    local most_prostitutes = 0
    for k,p in pairs(players.list(true, true, true)) do
        lapdances = get_lapdances_amount(p)
        prostitutes = get_prostitutes_solicited(p)
        horniness = lapdances + prostitutes
        if horniness > highest_horniness then
            highest_horniness = horniness
            horniest = p
            most_lapdances = lapdances
            most_prostitutes = prostitutes
        end
    end
    if horniness == nil then
        util.toast(translations.horniest_alone)
        return
    end
    if highest_horniness ~= 0 then
        return PLAYER.GET_PLAYER_NAME(horniest) .. translations.horniest_1 .. most_prostitutes .. translations.horniest_2 .. most_lapdances .. translations.horniest_3
    else
        util.toast(translations.horniest_fail)
        return nil
    end
end



function max_out_car(veh)
    for i=0, 47 do
        num = VEHICLE.GET_NUM_VEHICLE_MODS(veh, i)
        VEHICLE.SET_VEHICLE_MOD(veh, i, num -1, true)
    end
end

function ram_ped_with(ped, vehicle, offset, sog)
    request_model_load(vehicle)
    local front = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(ped, 0.0, offset, 0.0)
    front.x = front['x']
    front.y = front['y']
    front.z = front['z']
    local veh = entities.create_vehicle(vehicle, front, ENTITY.GET_ENTITY_HEADING(ped)+180)
    set_entity_face_entity(veh, ped, true)
    if ram_onground then
        OBJECT.PLACE_OBJECT_ON_GROUND_PROPERLY(veh)
    end
    VEHICLE.SET_VEHICLE_ENGINE_ON(veh, true, true, true)
    VEHICLE.SET_VEHICLE_FORWARD_SPEED(veh, 100.0)
end

function give_vehicle(pid, hash)
    request_model_load(hash)
    local plyr = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
    local c = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(plyr, 0.0, 5.0, 0.0)
    local car = entities.create_vehicle(hash, c, ENTITY.GET_ENTITY_HEADING(plyr))
    max_out_car(car)
    ENTITY.SET_ENTITY_INVINCIBLE(car)
    VEHICLE.SET_VEHICLE_DOOR_OPEN(car, 0, false, true)
    VEHICLE.SET_VEHICLE_DOOR_LATCHED(car, 0, false, false, true)
end

function give_vehicle_all(hash)
    for k,p in pairs(players.list(true, true, true)) do
        give_vehicle(p, hash)
    end
end

function attachto(offx, offy, offz, pid, angx, angy, angz, hash, bone, isnpc, isveh)
    local ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
    local bone = PED.GET_PED_BONE_INDEX(ped, bone)
    local coords = ENTITY.GET_ENTITY_COORDS(ped, true)
    coords.x = coords['x']
    coords.y = coords['y']
    coords.z = coords['z']
    if isnpc then
        obj = entities.create_ped(1, hash, coords, 90.0)
    elseif isveh then
        obj = entities.create_vehicle(hash, coords, 90.0)
    else
        obj = OBJECT.CREATE_OBJECT_NO_OFFSET(hash, coords['x'], coords['y'], coords['z'], true, false, false)
    end
    ENTITY.SET_ENTITY_INVINCIBLE(obj, true)
    ENTITY.ATTACH_ENTITY_TO_ENTITY(obj, ped, bone, offx, offy, offz, angx, angy, angz, false, false, true, false, 0, true)
    ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(obj, false, true)
end

function give_car_addon(pid, hash, center, ang)
    local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
    local pos = ENTITY.GET_ENTITY_COORDS(car, true)
    pos.x = pos['x']
    pos.y = pos['y']
    pos.z = pos['z']
    request_model_load(hash)
    local ramp = OBJECT.CREATE_OBJECT_NO_OFFSET(hash, pos['x'], pos['y'], pos['z'], true, false, false)
    local size = get_model_size(ENTITY.GET_ENTITY_MODEL(car))
    if center then
        ENTITY.ATTACH_ENTITY_TO_ENTITY(ramp, car, 0, 0.0, 0.0, 0.0, 0.0, 0.0, ang, true, true, true, false, 0, true)
    else
        ENTITY.ATTACH_ENTITY_TO_ENTITY(ramp, car, 0, 0.0, size['y']+1.0, 0.0, 0.0, 0.0, ang, true, true, true, false, 0, true)
    end
end

function give_all_car_addon(hash, center, ang)
    for k,pid in pairs(players.list(false, true, true)) do
        give_car_addon(pid, hash, center, ang)
    end
end

function attachall(offx, offy, offz, angx, angy, angz, hash, bone, isnpc, isveh)
    request_model_load(hash)
    for k, pid in pairs(players.list(false, true, true)) do
        attachto(offx, offy, offz, pid, angx, angy, angz, hash, bone, isnpc, isveh)
    end
end

-- INDIVIDUAL PLAYER SEGMENTS
num_attackers = 1
godmodeatk = false
freezeloop = false
atkhealth = 100
atk_critical_hits = true
freezetar = -1

function tp_player_car_to_coords(pid, coord)
    local name = PLAYER.GET_PLAYER_NAME(pid)
    local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
    if car ~= 0 then
        request_control_of_entity(car)
        if NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(car) then
            for i=1, 3 do
                util.toast(translations.success)
                ENTITY.SET_ENTITY_COORDS_NO_OFFSET(car, coord['x'], coord['y'], coord['z'], false, false, false)
            end
        end
    end
end

function tp_all_player_cars_to_coords(coord)
    for k,pid in pairs(players.list(false, true, true)) do
        tp_player_car_to_coords(pid, coord)
    end
end

function dispatch_griefer_jesus(target)
    griefer_jesus = util.create_thread(function(thr)
        util.toast(translations.grief_jesus_sent)
        request_model_load(-835930287)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(target)
        coords = ENTITY.GET_ENTITY_COORDS(target_ped, false)
        coords.x = coords['x']
        coords.y = coords['y']
        coords.z = coords['z']
        local jesus = entities.create_ped(1, -835930287, coords, 90.0)
        ENTITY.SET_ENTITY_INVINCIBLE(jesus, true)
        PED.SET_PED_HEARING_RANGE(jesus, 9999)
	    PED.SET_PED_CONFIG_FLAG(jesus, 281, true)
        PED.SET_PED_COMBAT_ATTRIBUTES(jesus, 5, true)
	    PED.SET_PED_COMBAT_ATTRIBUTES(jesus, 46, true)
        PED.SET_PED_CAN_RAGDOLL(jesus, false)
        WEAPON.GIVE_WEAPON_TO_PED(jesus, util.joaat("WEAPON_RAILGUN"), 9999, true, true)
        TASK.TASK_GO_TO_ENTITY(jesus, target_ped, -1, -1, 100.0, 0.0, 0)
    	TASK.TASK_COMBAT_PED(jesus, target_ped, 0, 16)
        PED.SET_PED_ACCURACY(jesus, 100.0)
        PED.SET_PED_COMBAT_ABILITY(jesus, 2)
        --pretty much just a respawn/rationale check
        while true do
            local player_coords = ENTITY.GET_ENTITY_COORDS(target_ped, false)
            local jesus_coords = ENTITY.GET_ENTITY_COORDS(jesus, false)
            local dist =  MISC.GET_DISTANCE_BETWEEN_COORDS(player_coords['x'], player_coords['y'], player_coords['z'], jesus_coords['x'], jesus_coords['y'], jesus_coords['z'], false)
            if dist > 100 then
                local behind = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(target_ped, -3.0, 0.0, 0.0)
                ENTITY.SET_ENTITY_COORDS(jesus, behind['x'], behind['y'], behind['z'], false, false, false, false)
            end
            -- if jesus disappears we can just make another lmao
            if not ENTITY.DOES_ENTITY_EXIST(jesus) then
                util.stop_thread()
            end
            local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(target)
            if not players.exists(target) then
                util.stop_thread()
            else
                TASK.TASK_COMBAT_PED(jesus, target_ped, 0, 16)
            end
            util.yield(100)
        end
    end)
end

function dispatch_angry_firefighter(target)
    angry_firefighter = util.create_thread(function(thr)
        local p_hash = util.joaat('s_m_y_fireman_01')
        local v_hash = util.joaat("firetruk")
        local player_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(target)
        request_model_load(p_hash)
        request_model_load(v_hash)
        local coords = ENTITY.GET_ENTITY_COORDS(player_ped, true)
        local spawn_pos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(player_ped, 0.0, -10.0, 0.0)
        local vehicle = entities.create_vehicle(v_hash, spawn_pos, ENTITY.GET_ENTITY_HEADING(player_ped))
        VEHICLE.SET_VEHICLE_SIREN(vehicle, true)
        local blip = HUD.ADD_BLIP_FOR_ENTITY(vehicle)
        HUD.SET_BLIP_COLOUR(blip, 61)
        ENTITY.SET_ENTITY_INVINCIBLE(vehicle, true)
        ENTITY.SET_ENTITY_INVINCIBLE(ped, true)
        local ped = entities.create_ped(1, p_hash, spawn_pos, 0.0)
        PED.SET_PED_INTO_VEHICLE(ped, vehicle, -1)
        PED.SET_PED_FLEE_ATTRIBUTES(ped, 0, false)
        PED.SET_PED_COMBAT_ATTRIBUTES(ped, 5, true)
        PED.SET_PED_COMBAT_ATTRIBUTES(ped, 46, true)
        TASK.TASK_VEHICLE_SHOOT_AT_PED(ped, player_ped, 1000.0)
        VEHICLE._SET_VEHICLE_DOORS_LOCKED_FOR_UNK(vehicle, true)
        VEHICLE.SET_VEHICLE_DOORS_LOCKED(vehicle, true)
        VEHICLE.SET_VEHICLE_DOORS_LOCKED_FOR_ALL_PLAYERS(vehicle, true)
        --pretty much just a respawn/rationale check
        while true do
            if not ENTITY.IS_ENTITY_UPRIGHT(vehicle, 30) then
                ENTITY.SET_ENTITY_ROTATION(vehicle, 0, 0, 0, 0) 
            end
            local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(target)
            local player_coords = ENTITY.GET_ENTITY_COORDS(target_ped, false)
            local ped_coords = ENTITY.GET_ENTITY_COORDS(ped, false)
            TASK.TASK_VEHICLE_SHOOT_AT_PED(ped, target_ped, 1000.0)
            PED.SET_PED_KEEP_TASK(ped, true)
            local dist =  MISC.GET_DISTANCE_BETWEEN_COORDS(player_coords['x'], player_coords['y'], player_coords['z'], ped_coords['x'], ped_coords['y'], ped_coords['z'], false)
            if dist > 50 then
                local behind = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(target_ped, -15.0, 0.0, 0.0)
                ENTITY.SET_ENTITY_COORDS(vehicle, behind['x'], behind['y'], behind['z'], false, false, false, false)
                TASK.TASK_VEHICLE_SHOOT_AT_PED(ped, target_ped, 1000.0)
                PED.SET_PED_KEEP_TASK(ped, true)
            end
            -- if jesus disappears we can just make another lmao
            if not ENTITY.DOES_ENTITY_EXIST(ped) then
                util.stop_thread()
            end
            if not players.exists(target) then
                util.stop_thread()
            end
            util.yield(100)
        end
    end)
end

function request_anim_dict(dict)
    while not STREAMING.HAS_ANIM_DICT_LOADED(dict) do
        STREAMING.REQUEST_ANIM_DICT(dict)
        util.yield()
    end
end

function dispatch_mariachi(target)
    mariachi_thr = util.create_thread(function()
        local men = {}
        local player_ped
        local pos_offsets = {-1.0, 0.0, 1.0}
        local p_hash = -927261102
        local pos
        request_model_load(p_hash)
        player_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(target)
        for i=1, 3 do
            local spawn_pos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(player_ped, pos_offsets[i], 1.0, 0.0)
            local ped = entities.create_ped(1, p_hash, spawn_pos, 0.0)
            local flag = entities.create_object(util.joaat("prop_flag_mexico"), spawn_pos, 0)
            ENTITY.SET_ENTITY_HEADING(ped, ENTITY.GET_ENTITY_HEADING(player_ped)+180)
            ENTITY.ATTACH_ENTITY_TO_ENTITY(flag, ped, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
            ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(ped, true, false)
            TASK.TASK_START_SCENARIO_IN_PLACE(ped, "WORLD_HUMAN_MUSICIAN", 0, false)
            PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(ped, true)
            PED.SET_PED_FLEE_ATTRIBUTES(ped, 0, false)
            PED.SET_PED_CAN_RAGDOLL(ped, false)
            ENTITY.SET_ENTITY_INVINCIBLE(ped, true)
            men[#men + 1] = ped
        end
    end)
end

givegun = false
function send_attacker(hash, pid, givegun, num_attackers, atkgun)
    local this_attacker
    local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
    coords = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(target_ped, 0.0, -3.0, 0.0)
    coords.x = coords['x']
    coords.y = coords['y']
    coords.z = coords['z']
    if hash ~= 'CLONE' then
        request_model_load(hash)
    end
    for i=1, num_attackers do
        if hash ~= 'CLONE' then
            this_attacker = entities.create_ped(28, hash, coords, math.random(0, 270))
        else
            this_attacker = PED.CLONE_PED(target_ped, true, true, true)
        end
        local blip = HUD.ADD_BLIP_FOR_ENTITY(this_attacker)
        HUD.SET_BLIP_COLOUR(blip, 61)
        if godmodeatk then
            ENTITY.SET_ENTITY_INVINCIBLE(this_attacker, true)
        end
        TASK.TASK_SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(this_attacker, true)
        PED.SET_PED_ACCURACY(this_attacker, 100.0)
        PED.SET_PED_COMBAT_ABILITY(this_attacker, 2)
        PED.SET_PED_AS_ENEMY(this_attacker, true)
        PED.SET_PED_FLEE_ATTRIBUTES(this_attacker, 0, false)
        PED.SET_PED_COMBAT_ATTRIBUTES(this_attacker, 46, true)
        TASK.TASK_COMBAT_PED(this_attacker, target_ped, 0, 16)
        if atkgun ~= 0 then
            WEAPON.GIVE_WEAPON_TO_PED(this_attacker, atkgun, 1000, false, true)
        end
        PED.SET_PED_MAX_HEALTH(this_attacker, atkhealth)
        ENTITY.SET_ENTITY_HEALTH(this_attacker, atkhealth)
        PED.SET_PED_SUFFERS_CRITICAL_HITS(this_attacker, atk_critical_hits)
    end
end

function send_aircraft_attacker(vhash, phash, pid, num_attackers)
    local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
    coords = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(target_ped, 1.0, 0.0, 500.0)
    coords.x = coords['x']
    coords.y = coords['y']
    coords.z = coords['z']
    request_model_load(vhash)
    request_model_load(phash)
    for i=1, num_attackers do
        coords.x = coords.x + i*2
        coords.y = coords.y + i*2
        local aircraft = entities.create_vehicle(vhash, coords, 0.0)
        VEHICLE.CONTROL_LANDING_GEAR(aircraft, 3)
        VEHICLE.SET_HELI_BLADES_FULL_SPEED(aircraft)
        VEHICLE.SET_VEHICLE_FORWARD_SPEED(aircraft, VEHICLE.GET_VEHICLE_ESTIMATED_MAX_SPEED(aircraft))
        if godmodeatk then
            ENTITY.SET_ENTITY_INVINCIBLE(aircraft, true)
        end
        for i= -1, VEHICLE.GET_VEHICLE_MODEL_NUMBER_OF_SEATS(vhash) - 2 do
            local ped = entities.create_ped(28, phash, coords, 30.0)
            local blip = HUD.ADD_BLIP_FOR_ENTITY(ped)
            HUD.SET_BLIP_COLOUR(blip, 61)
            if i == -1 then
                TASK.TASK_PLANE_MISSION(ped, aircraft, 0, target_ped, 0, 0, 0, 6, 0.0, 0, 0.0, 50.0, 40.0)
            end
            PED.SET_PED_COMBAT_ATTRIBUTES(ped, 5, true)
            PED.SET_PED_COMBAT_ATTRIBUTES(ped, 46, true)
            PED.SET_PED_INTO_VEHICLE(ped, aircraft, i)
            TASK.TASK_COMBAT_PED(ped, target_ped, 0, 16)
            PED.SET_PED_ACCURACY(ped, 100.0)
            PED.SET_PED_COMBAT_ABILITY(ped, 2)
        end
    end
end

function send_groundv_attacker(vhash, phash, pid, givegun, num_attackers, atkgun)
    local player_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
    request_model_load(vhash)
    local bike_hash = -159126838
    request_model_load(phash)
    for i=1, num_attackers do
        local spawn_pos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(player_ped, num_attackers-i, -10.0, 0.0)
        spawn_pos.x = spawn_pos['x']
        spawn_pos.y = spawn_pos['y']
        spawn_pos.z = spawn_pos['z']
        local bike = entities.create_vehicle(vhash, spawn_pos, ENTITY.GET_ENTITY_HEADING(player_ped))
        VEHICLE.SET_VEHICLE_ENGINE_ON(bike, true, true, false)
        for i=-1, VEHICLE.GET_VEHICLE_MODEL_NUMBER_OF_SEATS(vhash) - 2 do
            local rider = entities.create_ped(1, phash, spawn_pos, 0.0)
            local blip = HUD.ADD_BLIP_FOR_ENTITY(rider)
            HUD.SET_BLIP_COLOUR(blip, 61)
            if i == -1 then
                TASK.TASK_VEHICLE_CHASE(rider, target_ped)
            end
            max_out_car(atkbike)
            PED.SET_PED_INTO_VEHICLE(rider, bike, i)
            PED.SET_PED_COMBAT_ATTRIBUTES(rider, 5, true)
            PED.SET_PED_COMBAT_ATTRIBUTES(rider, 46, true)
            TASK.TASK_COMBAT_PED(rider, player_ped, 0, 16)
            if godmodeatk then
                ENTITY.SET_ENTITY_INVINCIBLE(bike, true)
                ENTITY.SET_ENTITY_INVINCIBLE(rider, true)
            end

            if atkgun ~= 0 then
                WEAPON.GIVE_WEAPON_TO_PED(rider, atkgun, 1000, false, true)
            end
        end
    end
end

function send_attacker_squad(p_hash, v_hash, forcestayinv, godmodeatk, hp, weapon, pid)
    local player_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
    request_model_load(p_hash)
    request_model_load(v_hash)
    local coords = ENTITY.GET_ENTITY_COORDS(player_ped, true)
    local spawn_pos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(player_ped, 0.0, -10.0, 0.0)
    local vehicle = entities.create_vehicle(v_hash, spawn_pos, ENTITY.GET_ENTITY_HEADING(player_ped)) 
    VEHICLE.SET_VEHICLE_ENGINE_ON(vehicle, true, true, false)
    max_out_car(vehicle)
    local blip = HUD.ADD_BLIP_FOR_ENTITY(vehicle)
    HUD.SET_BLIP_COLOUR(blip, 61)
    if godmodeatk then
        ENTITY.SET_ENTITY_INVINCIBLE(vehicle, true)
    end

    for i=-1, VEHICLE.GET_VEHICLE_MAX_NUMBER_OF_PASSENGERS(vehicle) - 1 do
        local ped = entities.create_ped(1, p_hash, spawn_pos, 0.0)
        PED.SET_PED_INTO_VEHICLE(ped, vehicle, i)
        if weapon ~= 0 then
            WEAPON.GIVE_WEAPON_TO_PED(ped, weapon, 1000, false, true)
        end
        ENTITY.SET_ENTITY_HEALTH(ped, hp)

        if hp > 100.0 then
            PED.SET_PED_SUFFERS_CRITICAL_HITS(ped, false)
            PED.SET_PED_CAN_RAGDOLL(ped, false)
        end
        PED.SET_PED_COMBAT_ATTRIBUTES(ped, 5, true)
        PED.SET_PED_COMBAT_ATTRIBUTES(ped, 46, true)
        if i == -1 then
            TASK.TASK_VEHICLE_CHASE(ped, player_ped)
        end
        TASK.TASK_COMBAT_PED(rider, player_ped, 0, 16)

        if godmodeatk then
            ENTITY.SET_ENTITY_INVINCIBLE(ped, true)
        end

        if forcestayinv then
            VEHICLE._SET_VEHICLE_DOORS_LOCKED_FOR_UNK(vehicle, true)
            VEHICLE.SET_VEHICLE_DOORS_LOCKED(vehicle, true)
        end
    end
end

function send_player_label_sms(label, pid)
    local event_data = {-791892894, players.user(), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    local out = label:sub(1, 127)
    for i = 0, #out -1 do
        local slot = i // 8
        local byte = string.byte(out, i + 1)
        event_data[slot + 3] = event_data[slot + 3] | byte << ( (i - slot * 8) * 8)
    end
    util.trigger_script_event(1 << pid, event_data)
end

vehicle_hashes = {util.joaat("dune2"), util.joaat("speedo2"), util.joaat("krieger"), util.joaat("kuruma"), util.joaat('insurgent'), util.joaat('neon'), util.joaat('akula'), util.joaat('alphaz1'), util.joaat('rogue'), util.joaat('oppressor2'), util.joaat('hydra')}
vehicle_names = {translations.v_1, translations.v_2, translations.v_3, translations.v_4, translations.v_5, translations.v_6, translations.v_7, translations.v_8, translations.v_9, translations.v_10, translations.v_11, translations.v_12, translations.custom}

function set_up_player_actions(pid)
    local childlock
    local atkgun = 0
    menu.divider(menu.player_root(pid), translations.script_name_pretty)
    local ls_friendly = menu.list(menu.player_root(pid), translations.ls_friendly, {translations.ls_friendly_cmd}, "")
    local ls_hostile = menu.list(menu.player_root(pid), translations.ls_hostile, {translations.ls_hostile_cmd}, "")
    local ls_neutral = menu.list(menu.player_root(pid), translations.ls_neutral, {translations.ls_neutral_cmd}, "")
    local spawnvehicle_root = menu.list(ls_friendly, translations.give_vehicle_root, {translations.give_vehicle_root_cmd}, "")
    local explosions_root = menu.list(ls_hostile, translations.projectiles_explosions, {translations.projectiles_explosions_cmd}, translations.projectiles_explosions_desc)
    local playerveh_root = menu.list(ls_hostile, translations.vehicle, {translations.p_vehicle_root_cmd}, translations.p_vehicle_root_desc)
    local npctrolls_root = menu.list(ls_hostile, translations.npc_trolling, {translations.npc_trolling_root_cmd}, "")
    local attackers_root = menu.list(npctrolls_root, translations.attackers, {translations.attackers_root_cmd}, "")
    local chattrolls_root = menu.list(ls_hostile, translations.chat_trolling, {translations.chat_trolling_cmd}, "")
    local pstats_root = menu.list(ls_hostile, translations.stats, {translations.p_stats_cmd}, "")

    ram_root = menu.list(ls_hostile, translations.ram, {translations.ram_cmd}, "")

    local tp_options = {translations.to_me, translations.to_waypoint, translations.maze_bank, translations.underwater, translations.high_up, translations.lsc, translations.scp_173, translations.large_cell, translations.underwater_child_lock}
    menu.list_action(playerveh_root, translations.teleport, {translations.teleport_cmd}, "", tp_options, function(index, value, click_type)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            local c = {}
            pluto_switch index do
                case 1:
                    c = ENTITY.GET_ENTITY_COORDS(players.user_ped(), true)
                    break
                case 2: 
                    c = get_waypoint_coords()
                    break
                case 3:
                    c.x = -75.261375
                    c.y = -818.674
                    c.z = 326.17517
                    break
                case 4: 
                    c.x = 4497.2207
                    c.y = 8028.3086
                    c.z = -32.635174
                    break
                case 5: 
                    c.x = 0.0
                    c.y = 0.0
                    c.z = 2000
                    break
                case 6: 
                    c.x = -353.84512
                    c.y = -135.59108
                    c.z = 39.009624
                    break
                case 7: 
                    c.x = 1642.8401
                    c.y = 2570.7695
                    c.z = 45.564854
                    break
                case 8:
                    c.x = 1737.1896
                    c.y = 2634.897
                    c.z = 45.56497
                    break
                case 9: 
                    menu.set_value(childlock, true)
                    c.x = 4497.2207
                    c.y = 8028.3086
                    c.z = -32.635174
                    break
            end
            tp_player_car_to_coords(pid, c)
        end
    end)

    local attach_options = {translations.to_car, translations.car_to_my_car, translations.my_car_to_their_car, translations.detach}
    menu.list_action(playerveh_root, translations.v_attach, {translations.v_attach_cmd}, "", attach_options, function(index, value, click_type)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            pluto_switch index do
                case 1: 
                    ENTITY.ATTACH_ENTITY_TO_ENTITY(players.user_ped(), car, 0, 0.0, -0.20, 2.00, 1.0, 1.0,1, true, true, true, false, 0, true)
                    break 
                case 2: 
                    if player_cur_car ~= 0 then
                        ENTITY.ATTACH_ENTITY_TO_ENTITY(car, player_cur_car, 0, 0.0, -5.00, 0.00, 1.0, 1.0,1, true, true, true, false, 0, true)
                    end
                    break
                case 3: 
                    if player_cur_car ~= 0 then
                        ENTITY.ATTACH_ENTITY_TO_ENTITY(player_cur_car, car, 0, 0.0, -5.00, 0.00, 1.0, 1.0,1, true, true, true, false, 0, true)
                    end
                    break

                case 4: 
                    ENTITY.DETACH_ENTITY(car, false, false)
                    if player_cur_car ~= 0 then
                        ENTITY.DETACH_ENTITY(player_cur_car, false, false)
                    end
                    ENTITY.DETACH_ENTITY(players.user_ped(), false, false)
                    break
            end
        end
    end)

    local vhp_options = {translations.v_destroy, translations.v_repair}
    menu.list_action(playerveh_root, translations.v_health, {translations.v_health_cmd},  translations.v_health_desc, vhp_options, function(index, value, click_type)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            VEHICLE.SET_VEHICLE_ENGINE_HEALTH(car, if index == 1 then -4000.0 else 10000.0)
            VEHICLE.SET_VEHICLE_BODY_HEALTH(car, if index == 1 then -4000.0 else 10000.0)
            if index == 2 then
                VEHICLE.SET_VEHICLE_FIXED(car)
            end
        end
    end)

    menu.action(playerveh_root, translations.yeet_vehicle, {translations.yeet_vehicle_cmd}, "", function(click_type)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            ENTITY.SET_ENTITY_MAX_SPEED(car, 10000000.0)
            ENTITY.APPLY_FORCE_TO_ENTITY(car, 1,  0.0, 0.0, 10000000, 0, 0, 0, 0, true, false, true, false, true)
        end
    end)

    menu.action(playerveh_root, translations.delete_vehicle, {translations.delete_vehicle_cmd}, "", function(click_type)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        entities.delete(car)
    end)

    childlock = menu.toggle_loop(playerveh_root, translations.child_lock, {translations.child_lock_cmd}, "", function()
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            VEHICLE.SET_VEHICLE_DOORS_LOCKED(car, 4)
        end
    end, function()
        if car ~= 0 then
            VEHICLE.SET_VEHICLE_DOORS_LOCKED(car, 1)
        end
    end)

    local door_options = {translations.open, translations.close, translations.d_break}
    menu.list_action(playerveh_root, translations.door_control, {translations.door_control_cmd}, "", door_options, function(index, value, click_type)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            local d = VEHICLE._GET_NUMBER_OF_VEHICLE_DOORS(car)
            for i=0, d do
                pluto_switch index do
                    case 1: 
                        VEHICLE.SET_VEHICLE_DOOR_OPEN(car, i, false, true)
                        break
                    case 2:
                        VEHICLE.SET_VEHICLE_DOOR_SHUT(car, i, true)
                        break
                    case 3:
                        VEHICLE.SET_VEHICLE_DOOR_BROKEN(car, i, false)
                        break
                end
            end
        end
    end)

    menu.action(playerveh_root, translations.p_godmode_vehicle, {translations.p_godmode_vehicle_cmd}, "", function(click_type)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            ENTITY.SET_ENTITY_INVINCIBLE(car, true)
            VEHICLE.SET_VEHICLE_CAN_BE_VISIBLY_DAMAGED(car, false)
        end
    end)

    menu.click_slider(playerveh_root, translations.p_vehicle_top_speed, {translations.p_vehicle_top_speed_cmd}, "", 0, 10000, 200, 100, function(s)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            VEHICLE.MODIFY_VEHICLE_TOP_SPEED(car, s)
            ENTITY.SET_ENTITY_MAX_SPEED(car, s)
        end
    end)

    menu.toggle(playerveh_root, translations.p_invisible_vehicle, {translations.p_invisible_vehicle_cmd}, "", function(on)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            if on then
                ENTITY.SET_ENTITY_ALPHA(car, 255)
                ENTITY.SET_ENTITY_VISIBLE(car, false, 0)
            else
                ENTITY.SET_ENTITY_ALPHA(car, 0)
                ENTITY.SET_ENTITY_VISIBLE(car, true, 0)
            end
        end
    end)

    menu.toggle(playerveh_root, translations.e_brake, {translations.e_brake_cmd}, "", function(on)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            VEHICLE.SET_VEHICLE_HANDBRAKE(car, on)
        end
    end)

    menu.toggle_loop(playerveh_root, translations.randomly_brake, {translations.randomly_brake_cmd}, "", function(on)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            VEHICLE.SET_VEHICLE_HANDBRAKE(car, true)
            util.yield(1000)
            request_control_of_entity(car)
            VEHICLE.SET_VEHICLE_HANDBRAKE(car, false)
            util.yield(math.random(3000, 15000))
        end
    end)

    menu.toggle(playerveh_root, translations.p_v_freeze, {translations.p_v_freeze_cmd}, "", function(on)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            speed = if on then 0.0 else 1000.0
            ENTITY.SET_ENTITY_MAX_SPEED(car, speed)
        end
    end)
    --SET_VEHICLE_ALARM(Vehicle vehicle, BOOL state)

    menu.action(playerveh_root, translations.burst_tires, {translations.burst_tires_cmd}, "", function(on)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            for i=0, 7 do
                VEHICLE.SET_VEHICLE_TYRE_BURST(car, i, true, 1000.0)
            end
        end
    end)
    
    menu.action(playerveh_root, translations.turn_vehicle_around, {translations.turn_vehicle_around_cmd}, "", function(on)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            local rot = ENTITY.GET_ENTITY_ROTATION(car, 0)
            local vel = ENTITY.GET_ENTITY_VELOCITY(car)
            ENTITY.SET_ENTITY_ROTATION(car, rot['x'], rot['y'], rot['z']+180, 0, true)
            ENTITY.SET_ENTITY_VELOCITY(car, -vel['x'], -vel['y'], vel['z'])
        end
    end)

    menu.action(playerveh_root, translations.p_flip_vehicle, {translations.p_flip_vehicle_cmd}, "", function(on)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            local rot = ENTITY.GET_ENTITY_ROTATION(car, 0)
            local vel = ENTITY.GET_ENTITY_VELOCITY(car)
            ENTITY.SET_ENTITY_ROTATION(car, rot['x'], rot['y']+180, rot['z'], 0, true)
            ENTITY.SET_ENTITY_VELOCITY(car, -vel['x'], -vel['y'], vel['z'])
        end
    end)

    menu.action(ls_friendly, translations.p_remove_stickybombs_from_car, {translations.p_remove_stickybombs_from_car_cmd}, "", function(click_type)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        NETWORK.REMOVE_ALL_STICKY_BOMBS_FROM_ENTITY(car)
    end)

    crush_root = menu.list(ls_hostile, translations.crush_player, {translations.crush_player_root_cmd}, "")

    local custom_crush_model = "dump"
    menu.text_input(crush_root, translations.custom_crush_model, {translations.custom_crush_model_cmd}, translations.custom_crush_model_desc, function(on_input)
        custom_crush_model = on_input
    end, 'dump')


    local crush_vehicle_hashes = {util.joaat('flatbed'), util.joaat('faggio'), util.joaat('speedo2')}
    local crush_vehicle_names = {translations.truck, translations.faggio, translations.clown_van, translations.custom}
    menu.list_action(crush_root, translations.crush_player, {translations.crush_player_cmd}, translations.crush_player_desc, crush_vehicle_names, function(index, value, click_type)
        if index == 4 then 
            hash = util.joaat(custom_crush_model)
        else
            hash = crush_vehicle_hashes[index]
        end
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        coords = ENTITY.GET_ENTITY_COORDS(target_ped, false)
        coords.x = coords['x']
        coords.y = coords['y']
        coords.z = coords['z'] + 20.0
        request_model_load(hash)
        local veh = entities.create_vehicle(hash, coords, 0.0)
    end)

    local obj_options = {translations.ramp, translations.barrier, translations.windmill, translations.radar}
    menu.list_action(ls_hostile, translations.spawn_object, {translations.spawn_object_cmd}, translations.spawn_object_desc, obj_options, function (index, value, click_type)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        pluto_switch index do 
            case 1:
                local hash = 2282807134
                request_model_load(hash)
                local ramp = spawn_object_in_front_of_ped(target_ped, hash, 90, 50.0, -1, true)
                local c = ENTITY.GET_ENTITY_COORDS(ramp, true)
                ENTITY.SET_ENTITY_COORDS_NO_OFFSET(ramp, c['x'], c['y'], c['z']-0.2, false, false, false)
                break
            case 2: 
                local hash = 3729169359
                local obj = spawn_object_in_front_of_ped(target_ped, hash, 0, 5.0, -0.5, false)
                ENTITY.FREEZE_ENTITY_POSITION(obj, true)
                break
            case 3: 
                local hash = 1952396163
                local obj = spawn_object_in_front_of_ped(target_ped, hash, 0, 5.0, -30, false)
                ENTITY.FREEZE_ENTITY_POSITION(obj, true)
                break
            case 4: 
                local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
                local hash = 2306058344
                local obj = spawn_object_in_front_of_ped(target_ped, hash, 0, 0.0, -5.0, false)
                ENTITY.FREEZE_ENTITY_POSITION(obj, true)
                break
        end
    end)

    local text_options = {translations.nudes, translations.random_texts}
    menu.list_action(ls_hostile, translations.text, {translations.text_p_cmd}, "", text_options, function(index, value, click_type)
        if index == 1 then
            for i=1, #sexts do
                send_player_label_sms(sexts[i], pid)
            end
        else
            for i=1, 100 do
                send_player_label_sms(all_labels[math.random(1, #all_labels)], pid)
                util.yield()
            end
        end
        util.toast(translations.texts_submitted)
    end)

    local v_model = 'lazer'
    menu.text_input(spawnvehicle_root, translations.give_vehicle_custom_vehicle_model, {translations.give_vehicle_custom_vehicle_model_cmd}, translations.give_vehicle_custom_vehicle_model_desc, function(on_input)
        v_model = on_input
    end, 'lazer')

    menu.list_action(spawnvehicle_root, translations.give_vehicle, {translations.give_vehicle_cmd}, "", vehicle_names, function(index, value, click_type)
        if value ~= translations.custom then 
            give_vehicle(pid, vehicle_hashes[index])
        else
            give_vehicle(pid, util.joaat(v_model))
        end
    end)

    local ram_car = "brickade"
    menu.text_input(ram_root, translations.custom_ram_vehicle, {translations.custom_ram_vehicle_cmd}, translations.custom_ram_vehicle_desc, function(on_input)
        ram_car = on_input
    end, "brickade")

    local ram_hashes = {-1007528109, -2103821244, 368211810, -1649536104}
    local ram_options = {translations.howard, translations.rally_truck, translations.cargo_plane, translations.phantom_wedge, translations.custom}
    menu.list_action(ram_root, translations.ram_with, {translations.ram_with_cmd}, "", ram_options, function(index, value, click_type)
        if value ~= translations.custom then
            ram_ped_with(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), ram_hashes[index], math.random(5, 15))
        else
            ram_ped_with(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), util.joaat(ram_car), math.random(5, 15))
        end
    end)

    local explo_types = {13, 12, 70}
    local explo_options = {translations.water_jet, translations.fire_jet, translations.launch_player}
    local explo_type_slider = menu.list_action(explosions_root, translations.explosion_type, {translations.explosion_type_cmd}, "", explo_options, function(index, value, click_type)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local coords = ENTITY.GET_ENTITY_COORDS(target_ped, false)
        e_type = explo_types[value]
        FIRE.ADD_EXPLOSION(coords['x'], coords['y'], coords['z'], e_type, 100.0, true, false, 0.0)
    end)

    menu.toggle_loop(explosions_root, translations.loop_explosion, {translations.loop_explosion_cmd}, translations.loop_explosion_desc, function(on)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local coords = ENTITY.GET_ENTITY_COORDS(target_ped)
        FIRE.ADD_EXPLOSION(coords['x'], coords['y'], coords['z'], explo_types[menu.get_value(explo_type_slider)], 1.0, true, false, 0.0)
    end)

    menu.toggle_loop(explosions_root, translations.random_explosion_loop, {translations.random_explosion_loop_cmd}, "", function(on)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local coords = ENTITY.GET_ENTITY_COORDS(target_ped)
        FIRE.ADD_EXPLOSION(coords['x'], coords['y'], coords['z'], math.random(0, 82), 1.0, true, false, 0.0)
    end)

    local p_types = {100416529, 126349499}
    local projectile_options = {translations.bullet, translations.snowball}
    menu.list_action(explosions_root, translations.projectile_type, {translations.projectile_type_cmd}, "", projectile_options, function(index, value, click_type)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local target = ENTITY.GET_ENTITY_COORDS(target_ped, false)
        local owner = players.user_ped()
        p_type = p_types[index]
        WEAPON.REQUEST_WEAPON_ASSET(p_type)
        MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(target['x'], target['y'], target['z']+0.5, target['x'], target['y'], target['z']+0.6, 100, true, p_type, owner, true, false, 4000.0)
    end)

    menu.toggle_loop(explosions_root, translations.projectile_loop, {translations.projectile_loop_cmd}, "", function(on)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local target = ENTITY.GET_ENTITY_COORDS(target_ped, false)
        local owner = players.user_ped()
        MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(target['x'], target['y'], target['z']+0.5, target['x'], target['y'], target['z']+0.6, 100, true, p_type, owner, true, false, 4000.0)
    end)

    menu.toggle(ls_neutral, translations.attach_to_player, {translations.attach_to_player_cmd}, translations.attach_to_player_desc, function(on)
        if PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid) == players.user_ped() then 
            util.toast(translations.crash_saved)
            return
        end
        if on then
            ENTITY.ATTACH_ENTITY_TO_ENTITY(players.user_ped(), PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), 0, 0.0, -0.20, 2.00, 1.0, 1.0,1, true, true, true, false, 0, true)
        else
            ENTITY.DETACH_ENTITY(players.user_ped(), false, false)
        end
    end)

    menu.action(ls_hostile, translations.chop_up, {translations.chop_up_cmd}, translations.chop_up_desc, function(click_type)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local coords = ENTITY.GET_ENTITY_COORDS(target_ped, false)
        coords.x = coords['x']
        coords.y = coords['y']
        coords.z = coords['z']+2.5
        local hash = util.joaat("buzzard")
        request_model_load(hash)
        local heli = entities.create_vehicle(hash, coords, ENTITY.GET_ENTITY_HEADING(target_ped))
        VEHICLE.SET_VEHICLE_ENGINE_ON(heli, true, true, false)
        VEHICLE.SET_HELI_BLADES_FULL_SPEED(heli)
        ENTITY.SET_ENTITY_INVINCIBLE(heli, true)
        ENTITY.FREEZE_ENTITY_POSITION(heli, true)
        ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(heli, true, true)
        ENTITY.SET_ENTITY_ROTATION(heli, 180, 0.0, ENTITY.GET_ENTITY_HEADING(target_ped), 0)
        ENTITY.SET_ENTITY_COORDS_NO_OFFSET(heli, coords.x, coords.y, coords.z, true, false, false)
        VEHICLE.SET_VEHICLE_ENGINE_ON(heli, true, true, true)
    end)

    menu.toggle(ls_hostile, translations.blackhole_target, {translations.blackhole_target_cmd}, translations.blackhole_target_desc, function(on)
        if on then
            if not blackhole then
                blackhole = true
                menu.trigger_commands(translations.blackhole .. " on")
            end
            bh_target = pid
        else
            bh_target = -1
            if blackhole then
                blackhole = false
                menu.trigger_commands(translations.blackhole .. " off")
            end
        end
    end)

    local atk_ped = "csb_stripper_02"
    menu.text_input(attackers_root, translations.atk_custom_ped, {translations.atk_custom_ped_cmd}, translations.atk_custom_ped_desc, function(on_input)
        atk_ped = on_input
    end, "csb_stripper_02")


    local atk_aicraft = "lazer"
    menu.text_input(attackers_root, translations.atk_custom_aircraft, {translations.atk_custom_aircraft_cmd}, translations.atk_custom_aircraft_desc, function(on_input)
        atk_aircraft = on_input
    end, "lazer")

    local atk_car = "adder"
    menu.text_input(attackers_root, translations.atk_custom_car, {translations.atk_custom_car_cmd}, translations.atk_custom_car_desc, function(on_input)
        atk_car= on_input
    end, "adder")
    
    local custom_atkgun = 'fists'
    menu.text_input(attackers_root, translations.custom_attacker_gun, {translations.custom_attacker_gun_cmd}, translations.custom_attacker_gun_desc, function(on_input)
        custom_atkgun = on_input
    end, 'Unarmed')

    local atk_guns = {translations.none, translations.pistol, translations.combat_pdw, translations.shotgun, translations.knife, translations.custom}
    menu.list_action(attackers_root, translations.weapon_to_give_to_attackers, {translations.weapon_to_give_to_attackers}, "", atk_guns, function(index, value, click_type)
        if value ~= translations.custom then
            atkgun = good_guns[index]
        else
            atkgun = util.joaat(custom_atkgun)
        end
    end)

    menu.toggle(attackers_root, translations.godmode_attackers, {translations.godmode_attackers_cmd}, "", function(on)
        godmodeatk = on
    end)

    menu.toggle(attackers_root, translations.suffer_crits, {translations.suffer_crits_cmd}, translations.suffer_crits_desc, function(on)
        atk_critical_hits = on
    end, true)

    menu.slider(attackers_root, translations.attacker_health, {translations.attacker_health_cmd}, "", 1, 10000, 100, 1, function(s)
        atkhealth = s
        if s > 100 then
            util.toast(translations.attacker_health_tip)
        end
      end)

    local num_attackers = 1
    menu.slider(attackers_root, translations.number_of_attackers, {translations.number_of_attackers_cmd}, "", 1, 10, 1, 1, function(s)
        num_attackers = s
    end)

    local attacker_hashes = {1459905209, -287649847, 1264920838, -927261102, 1302784073, -1788665315, 307287994, util.joaat('csb_stripper_02'), util.joaat("CS_BradCadaver")}
    local atk_options = {translations.jack_harlow, translations.niko, translations.chad, translations.mani, translations.lester, translations.dog,  translations.mountain_lion, translations.stripper, translations.brad, translations.custom, translations.custom_aircraft, translations.custom_car, translations.clone_player}
    menu.list_action(attackers_root, translations.send_normal_attacker, {translations.send_normal_attacker_cmd}, "", atk_options, function(index, value, click_type)
            pluto_switch index do
                case 10:
                    send_attacker(util.joaat(atk_ped), pid, false, num_attackers, atkgun)
                    break
                case 11: 
                    send_aircraft_attacker(util.joaat(atk_aircraft), -163714847, pid, num_attackers)
                    break
                case 12:
                    send_groundv_attacker(util.joaat(atk_car), 850468060, pid, true, num_attackers, atkgun)
                    break
                case 13: 
                    send_attacker("CLONE", pid, false, num_attackers)
                    break
                pluto_default:
                    send_attacker(attacker_hashes[index], pid, false, num_attackers, atkgun)
            end
    end)

    local specialatk_options = {translations.griefer_jesus, translations.angry_firefighter, translations.jets, translations.a_10s, translations.cargo_planes, translations.british, translations.clowns, translations.swat_assault, translations.juggernaut_onslaught, translations.motorcycle_gang, translations.helicopter}
    menu.list_action(attackers_root, translations.send_special_attacker, {translations.send_special_attacker_cmd}, "", specialatk_options, function(index, value, click_type)
            pluto_switch index do
                case 1: 
                    dispatch_griefer_jesus(pid)
                    break
                case 2: 
                    dispatch_angry_firefighter(pid)
                    break
                case 3:
                    send_aircraft_attacker(util.joaat('lazer'), -163714847, pid, num_attackers)
                    break
                case 4: 
                    send_aircraft_attacker(1692272545, -163714847, pid, num_attackers)
                    break
                case 5:
                    send_aircraft_attacker(util.joaat("cargoplane"), -163714847, pid, num_attackers)
                    break
                case 6: 
                    local hash = 0x9C9EFFD8
                    local player_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
                    request_model_load(hash)
                    request_model_load(util.joaat("prop_flag_uk"))
                    local coords = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(player_ped, 0.0, 2.0, 0.0)
                    coords.x = coords['x']
                    coords.y = coords['y']
                    coords.z = coords['z']
                    for i=1, 5 do
                        coords.x = coords['x']
                        coords.y = coords['y']
                        coords.z = coords['z']
                        local ped = entities.create_ped(28, hash, coords, 30.0)
                        local obj = OBJECT.CREATE_OBJECT_NO_OFFSET(util.joaat("prop_flag_uk"), coords['x'], coords['y'], coords['z'], true, false, false)
                        ENTITY.ATTACH_ENTITY_TO_ENTITY(obj, ped, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, true, false, 0, true)
                        PED.SET_PED_AS_ENEMY(ped, true)
                        PED.SET_PED_FLEE_ATTRIBUTES(ped, 0, false)
                        PED.SET_PED_COMBAT_ATTRIBUTES(ped, 46, true)
                        WEAPON.GIVE_WEAPON_TO_PED(ped, -1834847097, 0, false, true)
                        TASK.TASK_COMBAT_PED(ped, player_ped, 0, 16)
                    end
                    break
                case 7: 
                    send_attacker_squad(71929310, util.joaat("speedo2"), false, godmodeatk, 100.0, -1810795771, pid)
                    break
                case 8: 
                    send_attacker_squad(util.joaat('s_m_y_swat_01'), util.joaat("policet"), false, godmodeatk, 100.0, 2144741730, pid)
                    break
                case 9:
                    send_attacker_squad(util.joaat("u_m_y_juggernaut_01"), util.joaat("barracks3"), false, godmodeatk, 4000.0, 1119849093, pid)
                    break
                case 10: 
                    send_groundv_attacker(-159126838, 850468060, pid, true, num_attackers, atkgun)
                    break 
                case 11:
                    send_aircraft_attacker(1543134283, util.joaat("mp_m_bogdangoon"), pid, num_attackers)
                    break
            end
    end)

    local tow_options = {translations.from_front, translations.from_behind}
    menu.list_action(npctrolls_root, translations.tow_car, {translations.tow_car_cmd}, translations.tow_car_desc, tow_options, function(index, value, click_type)
        local player_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local last_veh = PED.GET_VEHICLE_PED_IS_IN(player_ped, true)
        local cur_veh = PED.GET_VEHICLE_PED_IS_IN(player_ped, false)
        if last_veh ~= 0 then
            if last_veh == cur_veh then
                kick_from_veh(pid)
                last_veh = cur_veh
                util.yield(2000)
            end
            request_control_of_entity(last_veh)
            tow_hash = -1323100960
            request_model_load(tow_hash)
            tower_hash = 0x9C9EFFD8
            request_model_load(tower_hash)
            local rots = ENTITY.GET_ENTITY_ROTATION(last_veh, 0)
            local dir = 5.0
            hdg = ENTITY.GET_ENTITY_HEADING(last_veh)
            if index == 2 then
                dir = -5.0
                hdg = hdg + 180
            end
            local coords = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(last_veh, 0.0, dir, 0.0)
            local tower = entities.create_ped(28, tower_hash, coords, 30.0)
            local towtruck = entities.create_vehicle(tow_hash, coords, hdg)
            ENTITY.SET_ENTITY_HEADING(towtruck, hdg)
            PED.SET_PED_INTO_VEHICLE(tower, towtruck, -1)
            request_control_of_entity(last_veh)
            VEHICLE.ATTACH_VEHICLE_TO_TOW_TRUCK(towtruck, last_veh, false, 0, 0, 0)
            TASK.TASK_VEHICLE_DRIVE_TO_COORD(tower, towtruck, math.random(1000), math.random(1000), math.random(100), 100, 1, ENTITY.GET_ENTITY_MODEL(last_veh), 4, 5, 0)
        end
    end)

    menu.action(npctrolls_root, translations.cat_explosion, {translations.cat_explosion_cmd}, translations.cat_explosion_desc, function(click_type)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local coords = ENTITY.GET_ENTITY_COORDS(target_ped, false)
        coords.x = coords['x']
        coords.y = coords['y']
        coords.z = coords['z']
        hash = util.joaat("a_c_cat_01")
        request_model_load(hash)
        for i=1, 30 do
            local cat = entities.create_ped(28, hash, coords, math.random(0, 270))
            local rand_x = math.random(-10, 10)*5
            local rand_y = math.random(-10, 10)*5
            local rand_z = math.random(-10, 10)*5
            ENTITY.SET_ENTITY_INVINCIBLE(cat, true)
            ENTITY.APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(cat, 1, rand_x, rand_y, rand_z, true, false, true, true)
            AUDIO.PLAY_PAIN(cat, 7, 0)
        end
    end)

    menu.action(ls_hostile, translations.drop_stickybomb, {translations.drop_stickybomb_cmd}, "", function(click_type)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local target = ENTITY.GET_ENTITY_COORDS(target_ped)
        local random_ped = get_random_ped()
        MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(target['x'], target['y'], target['z']+1, target['x'], target['y'], target['z'], 300.0, true, 741814745, random_ped, true, false, 100.0)
    end)

    --SET_VEHICLE_WHEEL_HEALTH(Vehicle vehicle, int wheelIndex, float health)
    menu.action(ls_hostile, translations.cage, {translations.cage_cmd}, "", function(click_type)
        local ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local coords = ENTITY.GET_ENTITY_COORDS(ped, true)
        coords.x = coords['x']
        coords.y = coords['y']
        coords.z = coords['z']
        local hash = 779277682
        request_model_load(hash)
        local cage1 = OBJECT.CREATE_OBJECT_NO_OFFSET(hash, coords['x'], coords['y'], coords['z'], true, false, false)
        ENTITY.SET_ENTITY_ROTATION(cage1, 0.0, -90.0, 0.0, 1, true)
        local cage2 = OBJECT.CREATE_OBJECT_NO_OFFSET(hash, coords['x'], coords['y'], coords['z'], true, false, false)
        ENTITY.SET_ENTITY_ROTATION(cage2, 0.0, 90.0, 0.0, 1, true)
    end)

    menu.action(npctrolls_root, translations.summon_mariachi_band, {translations.summon_mariachi_band_cmd}, translations.summon_mariachi_band_desc, function(click_type)
        dispatch_mariachi(pid)
    end)

    menu.action(ls_hostile, translations.cargo_plane_trap, {translations.cargo_plane_trap_cmd}, translations.cargo_plane_trap_desc, function(click_type)
        local ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local coords = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(ped, 0.0, 0.0, 0.0)
        coords.x = coords['x']
        coords.y = coords['y']
        coords.z = coords['z']
        local hash = util.joaat("cargoplane")
        request_model_load(hash)
        local cargo = entities.create_vehicle(hash, coords, ENTITY.GET_ENTITY_HEADING(ped))
        ENTITY.FREEZE_ENTITY_POSITION(cargo, true)
        ENTITY.SET_ENTITY_COORDS_NO_OFFSET(cargo, coords.x, coords.y, coords.z-0.1, true, false, false)
        ENTITY.SET_ENTITY_INVINCIBLE(cargo, true)
        for i=1, 5 do
            VEHICLE.SET_VEHICLE_DOOR_LATCHED(cargo, i, true, true, true)
        end
    end)

    menu.toggle_loop(ls_hostile, translations.earrape, {translations.earrape_cmd}, translations.earrape_desc, function(click_type)
        local ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        for i = 1, 20 do
            AUDIO.PLAY_SOUND_FROM_ENTITY(-1, "Bed", ped, "WastedSounds", true, true)
        end
        util.yield(500)
    end)

    menu.action(ls_hostile, translations.mark_as_angry_planes_target, {translations.mark_as_angry_planes_target_cmd}, translations.mark_as_angry_planes_target_desc, function(on_input)
        angry_planes_tar = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        if not angry_planes then
            util.toast(translations.angry_planes_auto)
            menu.trigger_commands(translations.angry_planes_cmd .. " on")
        end
    end)

    menu.action(chattrolls_root, translations.send_schizo_message, { translations.send_schizo_message_cmd}, translations.send_schizo_message_desc, function(click_type)
        util.toast(translations.schizo_pls_input)
        menu.show_command_box(translations.send_schizo_message_cmd .. PLAYER.GET_PLAYER_NAME(pid) .. " ")
        end, function(on_command)
            if #on_command > 140 then
                util.toast(translations.chat_too_long)
            else
                chat.send_targeted_message(pid, players.user(), on_command, false)
                util.toast(translations.message_sent)
            end
    end)

    
    menu.action(chattrolls_root, translations.invisible_spoof_chat, {translations.invisible_spoof_chat_cmd}, translations.invisible_spoof_chat_desc, function(click_type)
        util.toast(translations.schizo_pls_input)
        menu.show_command_box(translations.invisible_spoof_chat_cmd .. PLAYER.GET_PLAYER_NAME(pid) .. " ")
    end, function(on_command)
        if #on_command > 140 then
            util.toast(translations.chat_too_long)
        else
            for k,iter_pid in pairs(players.list(true, true, true)) do
                if iter_pid ~= pid then
                    chat.send_targeted_message(iter_pid, pid, on_command, false)
                end
            end
        end
    end)

    menu.action(chattrolls_root, translations.fake_rac_detection_chat, {translations.fake_rac_detection_chat_cmd}, translations.fake_rac_detection_chat_desc, function(click_type)
        local types = {'C1', 'I3', 'I1', 'N3', 'D3', 'S3'}
        local det_type = types[math.random(1, #types)]
        chat.send_message('> ' .. PLAYER.GET_PLAYER_NAME(pid) .. translations.triggered_rac_1 .. det_type .. translations.triggered_rac_2, false, true, true)
    end)

    menu.action(npctrolls_root, translations.clone, {translations.clone_cmd}, translations.clone_desc, function(click_type)
        local new_clone = PED.CLONE_PED(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true, true, true)
    end)

    local custom_hooker_options = {translations.clone_player, translations.lester, translations.tracy}
    menu.list_action(npctrolls_root, translations.send_custom_hooker, {translations.send_custom_hooker_cmd}, translations.send_custom_hooker_desc, custom_hooker_options, function(index, value, click_type)
        local hooker
        local c
        pluto_switch index do
            case 1:
                hooker = PED.CLONE_PED(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true, true, true)
                break
            case 2:
                c = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), -5.0, 0.0, 0.0)
                request_model_load(util.joaat('cs_lestercrest'))
                hooker = entities.create_ped(28, util.joaat('cs_lestercrest'), c, math.random(270))
                break
            case 3:
                c = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), -5.0, 0.0, 0.0)
                request_model_load(util.joaat('cs_tracydisanto'))
                hooker = entities.create_ped(28, util.joaat('cs_tracydisanto'), c, math.random(270))
                break
        end
        local c = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), -5.0, 0.0, 0.0)
        ENTITY.SET_ENTITY_COORDS(hooker, c.x, c.y, c.z)
        TASK.TASK_START_SCENARIO_IN_PLACE(hooker, "WORLD_HUMAN_PROSTITUTE_HIGH_CLASS", 0, false)
    end)
    --ba_prop_club_glass_trans

    menu.action(npctrolls_root, translations.npc_jack_last_car, {translations.npc_jack_last_car_cmd}, translations.npc_jack_last_car_desc, function(click_type)
        npc_jack(pid, false)
    end)

    menu.toggle(npctrolls_root, translations.nearby_peds_combat_player, {translations.nearby_peds_combat_player_desc}, "", function(on)
        combat_tar = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        aped_combat = on
        mod_uses("ped", if on then 1 else -1)
    end)

    menu.action(npctrolls_root, translations.fill_car_with_peds, {translations.fill_car_with_peds_cmd}, "", function(click_type)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        if PED.IS_PED_IN_ANY_VEHICLE(target_ped, true) then
                local veh = PED.GET_VEHICLE_PED_IS_IN(target_ped, false)
                local success = true
                while VEHICLE.ARE_ANY_VEHICLE_SEATS_FREE(veh) do
                    util.yield()
                    --  sometimes peds fail to get seated, so we will have something to break after 20 attempts if things go south
                    local iteration = 0
                    if iteration >= 20 then
                        local success = false
                        iteration = 0
                        break
                    end
                    local iteration = iteration + 1
                    local nearby_peds = entities.get_all_peds_as_handles()
                    for k,ped in pairs(nearby_peds) do
                        if PED.GET_VEHICLE_PED_IS_IN(ped, false) ~= veh and ENTITY.GET_ENTITY_HEALTH(ped) > 0 and not PED.IS_PED_FLEEING(ped) then
                            --dont touch player peds
                            if(PED.GET_PED_TYPE(ped) > 4) then
                                local veh = PED.GET_VEHICLE_PED_IS_IN(target_ped, false)
                                local iteration = iteration + 1
                                    for index = 0, VEHICLE.GET_VEHICLE_MODEL_NUMBER_OF_SEATS(ENTITY.GET_ENTITY_MODEL(veh)) do
                                        if VEHICLE.IS_VEHICLE_SEAT_FREE(veh, index) then
                                            -- i think requesting control and clearing task deglitches the peds
                                            -- this is specifically to counter weird A-posing
                                            -- EDIT: it doesnt. why the fuck do some peds a-pose??? maybe ill find out eventually. oh well.
                                            request_control_of_entity(ped)
                                            TASK.CLEAR_PED_TASKS_IMMEDIATELY(ped)
                                            PED.SET_PED_INTO_VEHICLE(ped, veh, index)
                                            PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(ped, true)
                                            PED.SET_PED_COMBAT_ATTRIBUTES(ped, 5, true)
                                            PED.SET_PED_FLEE_ATTRIBUTES(ped, 0, false)
                                            PED.SET_PED_COMBAT_ATTRIBUTES(ped, 46, true)
                                            PED.SET_PED_CAN_BE_DRAGGED_OUT(ped, false)
                                            PED.SET_PED_CAN_BE_KNOCKED_OFF_VEHICLE(ped, false)
                                        end
                                    end
                                break
                            end
                        end
                    end
                end
                if success then
                    util.toast(translations.fill_car_success)
                end
        end
    end)

    -- these actions should only run when the user is fully loaded in, i.e for memory stuff
        while util.is_session_transition_active() or not NETWORK.NETWORK_IS_PLAYER_ACTIVE(pid) do
            util.yield()
        end
        if pstats_root ~= nil then
            -- thanks vsus
            menu.action(pstats_root, translations.lap_dances_received .. tostring(get_lapdances_amount(pid)), {translations.lap_dances_received_cmd}, translations.lap_dances_received_desc, function(click_type)
                chat.send_message(PLAYER.GET_PLAYER_NAME(pid) .. translations.has_purchased .. tostring(get_lapdances_amount(pid)) .. translations.lap_dances_in_total, false, true, true)
            end)

            menu.action(pstats_root, translations.hookers_bought .. tostring(get_prostitutes_solicited(pid)), {translations.hookers_bought_cmd}, translations.hookers_bought_desc, function(click_type)
                chat.send_message(PLAYER.GET_PLAYER_NAME(pid) .. translations.has_solicited .. tostring(get_prostitutes_solicited(pid)) .. translations.hookers_in_total, false, true, true)
            end)
        end
end

broke_blips = {}
broke_radar = false
menu.toggle(aphostile_root, translations.broke_radar, {translations.broke_radar_cmd}, translations.broke_radar_desc, function(on)
    broke_radar = on
    mod_uses("player", if on then 1 else -1)
    if not on then
        broke_radar = false
        mod_uses("player", -1)
        for plyr,blip in pairs(broke_blips) do
            util.remove_blip(blip)
            broke_blips[plyr] = nil
        end
    end
end)

earrape_all = false
menu.toggle(aphostile_root, translations.earrape, {translations.earrape_all_cmd}, translations.earrape_desc, function(on)
    earrape_all = on
    mod_uses("player", if on then 1 else -1)
end)


broke_threshold = 1000000
menu.slider(aphostile_root, translations.broke_threshold, {translations.broke_threshold_cmd}, translations.broke_threshold_desc, 100000, 1000000000, 1000000, 100000, function(s)
    broke_threshold = s
  end)


antioppressor = false
menu.toggle(ap_root, translations.antioppressor, { translations.antioppressor_cmd},  translations.antioppressor_desc, function(on)
    antioppressor = on
    mod_uses("player", if on then 1 else -1)
end)

noarmedvehs = false
menu.toggle(ap_root, translations.delete_armed_vehicles, {translations.delete_armed_vehicles_cmd}, translations.delete_armed_vehicles_desc, function(on)
    noarmedvehs = on
    mod_uses("player", if on then 1 else -1)
end)


menu.action(aphostile_root, translations.mass_spoof_chat, {translations.mass_spoof_chat}, translations.mass_spoof_chat_desc, function(click_type)
    util.toast(translations.mass_chat_input)
    menu.show_command_box(translations.mass_spoof_chat_cmd .. " ")
end, function(on_command)
    if #on_command > 140 then
        util.toast(translations.chat_too_long)
    else
        for k,pid1 in pairs(players.list(false, true, true)) do
            for k,pid2 in pairs(players.list(true, true, true)) do
                chat.send_targeted_message(pid2, pid1, on_command, false)
            end
        end
    end
end)

local text_options = {translations.nudes, translations.random_texts}
menu.list_action(apneutral_root, translations.text, {translations.text_all_cmd}, "", text_options, function(index, value, click_type)
    for k,pid in pairs(players.list(false, true, true)) do
        if index == 1 then
            for i=1, #sexts do
                send_player_label_sms(sexts[i], pid)
            end
        else
            for i=1, 100 do
                send_player_label_sms(all_labels[math.random(1, #all_labels)], pid)
                util.yield()
            end
        end
    end
    util.toast(translations.texts_submitted)
end)


menu.action(ap_root, translations.toast_best_mug_target, {translations.toast_best_mug_target_cmd}, translations.toast_best_mug_target_desc, function(click_type)
    local ret = get_best_mug_target()
    if ret ~= nil then
        util.toast(ret)
    end
end)


local announce_options = {translations.best_mug_target, translations.poorest_player, translations.richest_player, translations.horniest_player}
menu.list_action(ap_root, translations.announce, {translations.announce_cmd}, "", announce_options, function(index, value, click_type)
    local ret = nil
    pluto_switch index do 
        case 1: 
            ret = get_best_mug_target()
            break
        case 2: 
            ret = get_poorest_player()
            break
        case 3:
            ret = get_richest_player()
            break
        case 4:
            ret = get_horniest_player()
            break
    end
    if ret ~= nil then
        chat.send_message(ret, false, true, true)
    end
end)

menu.action(aphostile_root, translations.kick_all_non_friends, {translations.kick_all_non_friends_cmd}, translations.kick_all_non_friends_desc, function(click_type)
    local victims = players.list(fals, false, true)
    for k,pid in pairs(victims) do
        menu.trigger_commands(translations.kick_cmd .. PLAYER.GET_PLAYER_NAME(pid))
    end
end)

infibounty_amt = 10000
menu.slider(aphostile_root, translations.infibounty_amount, {translations.infibounty_amount_cmd}, "", 0, 10000, 10000, 1, function(s)
    infibounty_amt = s
  end)


menu.toggle_loop(aphostile_root, translations.infibounty, {translations.infibounty_cmd}, translations.infibounty_desc, function(click_type)
    menu.trigger_commands(translations.bountyall_cmd .. tostring(infibounty_amt))
    util.yield(60000)
end)

menu.action(aphostile_root, translations.crash_all, {translations.crash_all_cmd}, translations.crash_all_desc, function(click_type)
    -- obfuscation to prevent patching
    -- if you are unobfuscating this to steal my crash for your shitty lua that like probably nobody downloads on 2take1 or cherax: fuck you
    -- learn your own shit! how unique is something if everyone has it? learn some new tricks, i beg you. 
    -- lancescript on top!
    if not STREAMING.IS_MODEL_IN_CDIMAGE(0x573201B8) then
        util.toast(translations.crashall_failed)
    end
    request_model_load(0x573201B8)
    ENTITY.SET_ENTITY_COORDS(players.user_ped(), 0.0, 0.0, 2000.0, false, false, false, false)
    local crash_keys = {"NULL", "VOID", "NaN", "127563/0", "NIL"}
    local crash_table = {109, 101, 110, 117, 046, 116, 114, 105, 103, 103, 101, 114, 095, 099, 111, 109, 109, 097, 110, 100, 115, 040}
    util.toast(translations.crashall_initiated)
    -- if we don't yield for a second, the user will never see this warning
    util.yield(500)
    local crash_str = ""
    for k,v in pairs(crash_table) do
        crash_str = crash_str .. string.char(crash_table[k])
    end
    for k,v in pairs(crash_keys) do
        print(k + (k*128))
    end
    -- wait a few seconds while in safety area to prevent crashing self
    local st_time = os.time()
    while os.time() - st_time < 5 do
        ENTITY.SET_ENTITY_COORDS(players.user_ped(), 0.0, 0.0, 2000.0, false, false, false, false)
    end
    local crash_compiled_func = load(crash_str .. '\"' .. memory.read_string(util_alloc) .. '\")')
    pcall(crash_compiled_func)
    if true and (not not true) and 1267836782 > 1 and #players.list(true, true, true) == 1 then
        util.toast(translations.peace)
    else
        util.toast(translations.crashall_failed2)
    end

    -- if you know whats going on here, please dont spoil how this works or reveal the crash method, it took me a few days to discover >_<
end)

apgiveveh_root = menu.list(apfriendly_root, translations.give_vehicle_root, {translations.give_all_vehicle_root_cmd}, "")

local allv_model = 'lazer'
menu.text_input(apgiveveh_root, translations.give_vehicle_custom_vehicle_model, {translations.give_all_vehicle_custom_model_cmd}, translations.give_vehicle_custom_vehicle_model_desc, function(on_input)
    v_model = on_input
end, 'lazer')


menu.list_action(apgiveveh_root, translations.give_vehicle, {translations.give_all_vehicle_final_cmd}, "", vehicle_names, function(index, value, click_type)
    if value ~= "Custom" then 
        give_vehicle_all(vehicle_hashes[index])
    else
        give_vehicle_all(util.joaat(allv_model))
    end
end)

show_voicechatters = false
menu.toggle(online_root, translations.show_me_whos_using_voicechat, {translations.show_me_whos_using_voicechat_cmd}, translations.show_me_whos_using_voicechat_desc, function(on)
    show_voicechatters = on
    mod_uses("player", if on then 1 else -1)
end)


cur_names = {}
players.on_join(function(pid)
    if pid ~= players.user() then
        local name = PLAYER.GET_PLAYER_NAME(pid)
        cur_names[pid+1] = name
    end
    set_up_player_actions(pid)
end)
players.dispatch_on_join()

players.on_leave(function(pid)
    if broke_blips[pid] ~= nil then
        broke_blips[pid] = nil
        util.remove_blip(broke_blips[pid])
    end
end)



players_thread = util.create_thread(function (thr)
    while true do
        if player_uses > 0 then
            if show_updates then
                util.toast("Player pool is being updated")
            end
            all_players = players.list(false, true, true)
            for k,pid in pairs(all_players) do
                if friendtect then
                    local hdl = pid_to_handle(pid)
                    local ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
                    -- check if player is dead, and player is our friend
                    if ENTITY.IS_ENTITY_DEAD(ped) and NETWORK.NETWORK_IS_FRIEND(hdl) then
                        -- did player die just 1 second (or so..) ago?
                        if MISC.GET_GAME_TIMER() - PED.GET_PED_TIME_OF_DEATH(ped) <= 1 then
                            local killer = PED.GET_PED_SOURCE_OF_DEATH(ped)
                            if ENTITY.IS_ENTITY_A_PED(killer) then
                                if PLAYER.IS_PED_A_PLAYER(killer) then
                                    local plyr = NETWORK.NETWORK_GET_PLAYER_INDEX_FROM_PED(killer)
                                    local killer_hdl = pid_to_handle(killer)
                                    -- allow friends to kill other friends
                                    if plyr ~= 0 and ped ~= killer and not NETWORK.NETWORK_IS_FRIEND(killer_hdl) then
                                        local name = PLAYER.GET_PLAYER_NAME(plyr)
                                        menu.trigger_commands("kill" .. name)
                                    end
                                else
                                    -- if they a ped, kill them
                                    ENTITY.SET_ENTITY_HEALTH(killer, 0.0)
                                end
                            end
                        end
                    end
                end
                if earrape_all then
                    local this_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
                    for i = 1, 20 do
                        AUDIO.PLAY_SOUND_FROM_ENTITY(-1, "Bed", this_ped, "WastedSounds", true, true)
                    end
                end
                if protected_areas_on then
                    for k,v in pairs(protected_areas) do
                        local c = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), false)
                        local dist = MISC.GET_DISTANCE_BETWEEN_COORDS(c.x, c.y, c.z, v.x, v.y, v.z, true)
                        if dist < v.radius then
                            local hdl = pid_to_handle(pid)
                            local rid = players.get_rockstar_id(pid)
                            kill_this_guy = true
                            if protected_area_allow_friends then
                                if NETWORK.NETWORK_IS_FRIEND(hdl) then
                                    kill_this_guy = false
                                end
                            end
                            if protected_area_kill_armed then
                                -- default to false
                                kill_this_guy = false
                                if WEAPON.GET_SELECTED_PED_WEAPON(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)) ~= -1569615261 then
                                    kill_this_guy = true
                                end
                            end
                            if kill_this_guy then
                                MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(c.x, c.y, c.z, c.x, c.y, c.z+0.1, 300.0, true, 100416529, players.user_ped(), true, false, 100.0)
                            end
                        end
                    end
                end
                if antioppressor then
                    local ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
                    local vehicle = PED.GET_VEHICLE_PED_IS_IN(ped, true)
                    if vehicle ~= 0 then
                      local hash = util.joaat("oppressor2")
                      if VEHICLE.IS_VEHICLE_MODEL(vehicle, hash) then
                        entities.delete(vehicle)
                      end
                    end
                end

                if noarmedvehs then
                    local ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
                    local vehicle = PED.GET_VEHICLE_PED_IS_IN(ped, true)
                    if vehicle ~= 0 then
                        if VEHICLE.DOES_VEHICLE_HAVE_WEAPONS(vehicle) then 
                            entities.delete(vehicle)
                        end
                    end
                end

                if broke_radar then
                    total_asset = players.get_wallet(pid) + players.get_bank(pid)
                    if total_asset < broke_threshold then
                        b_coords = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
                        if broke_blips[pid] == nil then
                            blip = HUD.ADD_BLIP_FOR_RADIUS(b_coords.x, b_coords.y, b_coords.z, 100.0)
                            broke_blips[pid] = blip
                            HUD.SET_BLIP_COLOUR(blip, 81)
                            HUD.SET_BLIP_ALPHA(blip, 128)
                        else
                            blip = broke_blips[pid]
                        end
                        HUD.SET_BLIP_COORDS(blip, b_coords.x, b_coords.y, b_coords.z)
                    else
                        if broke_blips[pid] ~= nil then
                            blip = broke_blips[pid]
                            util.remove_blip(blip)
                            broke_blips[pid] = nil
                        end
                    end
                end

                if show_voicechatters then
                    ls_log("show voicechatters")
                    if NETWORK.NETWORK_IS_PLAYER_TALKING(pid) then
                        util.toast(PLAYER.GET_PLAYER_NAME(pid) .. " is talking")
                    end
                end
            end
        
        end
        util.yield()
    end
end)

-- LANCESCRIPT OPTIONS
menu.toggle(lancescript_root, translations.debug, {translations.debug_cmd}, "", function(on)
    ls_debug = on
end)

menu.list_action(lancescript_root, translations.select_lang, {translations.select_langcmd}, "", just_translation_files, function(index, value, click_type)
    local file = io.open(selected_lang_path, 'w')
    file:write(value)
    file:close()
    util.stop_script()
end, selected_language)


--OPEN_ONLINE_POLICIES_MENU


-- CREDITS
lancescript_credits = menu.list(lancescript_root, translations.credits, {translations.credits_cmd}, "")
menu.action(lancescript_credits, "Sainan", {}, translations.cr_sainan, function(click_type) end)
menu.action(lancescript_credits, "Catnip#0420", {}, translations.cr_catnip, function(click_type) end)
menu.action(lancescript_credits, "PANDA", {}, translations.cr_panda, function(click_type) end)
menu.action(lancescript_credits, "Prism#7717", {}, translations.cr_prism, function(click_type) end)
menu.action(lancescript_credits, "Ayim#7708", {}, translations.cr_ayim, function(click_type) end)
menu.action(lancescript_credits, "Millennium#0001", {}, translations.cr_millennium, function(click_type) end)
menu.action(lancescript_credits, "61k", {}, translations.cr_61k, function(click_type) end)
menu.action(lancescript_credits, "Y1tzy", {}, translations.cr_yitzy, function(click_type) end)
menu.action(lancescript_credits, "Lancito01", {}, translations.cr_lancito, function(click_type) end)
menu.action(lancescript_credits, "YoYo", {}, translations.cr_yoyo, function(click_type) end)
menu.action(lancescript_credits, "QuickNET", {}, translations.cr_quicknet, function(click_type) end)
menu.action(lancescript_credits, "ICYPhoenix", {}, translations.cr_icy, function(click_type) end)
menu.action(lancescript_credits, "Jerrrry123", {}, translations.cr_jerry, function(click_type) end)
menu.action(lancescript_credits, "aaronlink127", {}, translations.cr_aaronlink, function(click_type) end)
menu.action(lancescript_credits, "Axhov", {}, translations.cr_axhov , function(click_type) end)
menu.action(lancescript_credits, "Nowiry", {}, translations.cr_nowiry, function(click_type) end)
menu.action(lancescript_credits, "ZERO", {}, translations.cr_zero, function(click_type) end)

-- SCRIPT IS "FINISHED LOADING"
is_loading = false

-- ON CHAT HOOK
chat.on_message(function(packet_sender, message_sender, text, team_chat)
end)

-- ## MAIN TICK LOOP ## --
while true do
    for k,v in pairs(ped_flags) do
        if v ~= nil and v then
            PED.SET_PED_CONFIG_FLAG(players.user_ped(), k, true)
        end
    end
    player_cur_car = entities.get_user_vehicle_as_handle()
    -- MY VEHICLE LOOP SHIT
    if mph_plate then
        if player_cur_car ~= 0 then
            if mph_unit == "KPH" then
                unit_conv = 3.6
            else
                unit_conv = 2.236936
            end
            speed = math.ceil(ENTITY.GET_ENTITY_SPEED(player_cur_car)*unit_conv)
            VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(player_cur_car, speed .. " " .. mph_unit)
        end
    end

    -- "dow block" is an invisible platform that is continuously teleported under the vehicle/player for the illusion
    -- sometimes other players see this. sometimes they don't.
    if walkonwater or driveonwater or driveonair then
        if dow_block == 0 or not ENTITY.DOES_ENTITY_EXIST(dow_block) then
            local hash = util.joaat("stt_prop_stunt_bblock_mdm3")
            request_model_load(hash)
            local c = {}
            c.x = 0.0
            c.y = 0.0
            c.z = 0.0
            dow_block = OBJECT.CREATE_OBJECT_NO_OFFSET(hash, c['x'], c['y'], c['z'], true, false, false)
            ENTITY.SET_ENTITY_ALPHA(dow_block, 0)
            ENTITY.SET_ENTITY_VISIBLE(dow_block, false, 0)
        end
    end

    if dow_block ~= 0 and not walkonwater and not walkonair and not driveonwater and not driveonair then
        ENTITY.SET_ENTITY_COORDS_NO_OFFSET(dow_block, 0, 0, 0, false, false, false)
    end

    if walkonwater then
        local car = PED.GET_VEHICLE_PED_IS_IN(players.user_ped(), false)
        if car == 0 then
            local pos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(players.user_ped(), 0.0, 2.0, 0.0)
            -- we need to offset this because otherwise the player keeps diving off the thing, like a fucking dumbass
            -- ht isnt actually used here, but im allocating some memory anyways to prevent a possible crash, probably. idk im no computer engineer
            local ht = memory.alloc(4)
            -- this is better than ENTITY.IS_ENTITY_IN_WATER because it can detect if a player is actually above water without them even being "in" it
            if WATER.GET_WATER_HEIGHT(pos['x'], pos['y'], pos['z'], ht) then
                local t, z = util.get_ground_z(pos['x'], pos['y'], pos['z'])
                if t then
                    ENTITY.SET_ENTITY_COORDS_NO_OFFSET(dow_block, pos['x'], pos['y'], z, false, false, false)
                    ENTITY.SET_ENTITY_HEADING(dow_block, ENTITY.GET_ENTITY_HEADING(players.user_ped()))
                end
            end
        end
    end

    if driveonwater then
        if player_cur_car ~= 0 then
            local pos = ENTITY.GET_ENTITY_COORDS(player_cur_car, true)
            -- ht isnt actually used here, but im allocating some memory anyways to prevent a possible crash, probably. idk im no computer engineer
            local ht = memory.alloc(4)
            -- this is better than ENTITY.IS_ENTITY_IN_WATER because it can detect if a player is actually above water without them even being "in" it
            if WATER.GET_WATER_HEIGHT(pos['x'], pos['y'], pos['z'], ht) then
                local t, z = util.get_ground_z(pos['x'], pos['y'], pos['z'])
                if t then
                    ENTITY.SET_ENTITY_COORDS_NO_OFFSET(dow_block, pos['x'], pos['y'], z, false, false, false)
                    ENTITY.SET_ENTITY_HEADING(dow_block, ENTITY.GET_ENTITY_HEADING(player_cur_car))
                end
            end
        else
            ENTITY.SET_ENTITY_COORDS_NO_OFFSET(dow_block, 0, 0, 0, false, false, false)
        end
    end

    if driveonair then
        if player_cur_car ~= 0 then
            local pos = ENTITY.GET_ENTITY_COORDS(player_cur_car, true)
            local boxpos = ENTITY.GET_ENTITY_COORDS(dow_block, true)
            if MISC.GET_DISTANCE_BETWEEN_COORDS(pos['x'], pos['y'], pos['z'], boxpos['x'], boxpos['y'], boxpos['z'], true) >= 5 then
                ENTITY.SET_ENTITY_COORDS_NO_OFFSET(dow_block, pos['x'], pos['y'], doa_ht, false, false, false)
                ENTITY.SET_ENTITY_HEADING(dow_block, ENTITY.GET_ENTITY_HEADING(player_cur_car))
            end
            if PAD.IS_CONTROL_PRESSED(22, 22) then
                doa_ht = doa_ht + 0.1
                ENTITY.SET_ENTITY_COORDS_NO_OFFSET(dow_block, pos['x'], pos['y'], doa_ht, false, false, false)
            end
            if PAD.IS_CONTROL_PRESSED(36, 36) then
                doa_ht = doa_ht - 0.1
                ENTITY.SET_ENTITY_COORDS_NO_OFFSET(dow_block, pos['x'], pos['y'], doa_ht, false, false, false)
            end
        end
    end

    if v_fly then
        if PED.GET_VEHICLE_PED_IS_IN(players.user_ped(), false) ~= v_f_plane then
            menu.set_value(ls_vehiclefly, false)
        end
    end

    if cinematic_autod then
        ls_log("auto cinema drive")
        if CAM._IS_CINEMATIC_CAM_ACTIVE() then
            if not cinestate_active then
                local goto_coords = get_waypoint_coords()
                if goto_coords ~= nil then
                    TASK.TASK_VEHICLE_DRIVE_TO_COORD_LONGRANGE(players.user_ped(), player_cur_car, goto_coords['x'], goto_coords['y'], goto_coords['z'], 300.0, 786996, 5)
                    cinestate_active = true
                end
            end
        else
            if cinestate_active then
                cinestate_active = false
                TASK.CLEAR_PED_TASKS(players.user_ped())
            end
        end
                    --TASK.TASK_VEHICLE_DRIVE_TO_COORD_LONGRANGE(players.user_ped(), player_cur_car, goto_coords['x'], goto_coords['y'], goto_coords['z'], 300.0, 786996, 5)
    end

    -- ## WEAPONS SHIT
    if grapplegun then
        ls_log("grapple hook loop")
        local curwep = WEAPON.GET_SELECTED_PED_WEAPON(players.user_ped())
        if PED.IS_PED_SHOOTING(players.user_ped()) and PED.GET_VEHICLE_PED_IS_IN(players.user_ped(), false) then
            if curwep == util.joaat("weapon_pistol") or curwep == util.joaat("weapon_pistol_mk2") then
                ls_log("ghook control pressed")
                local raycast_coord = raycast_gameplay_cam(-1, 10000.0)
                if raycast_coord[1] == 1 then
                    local lastdist = nil
                    TASK.TASK_SKY_DIVE(players.user_ped())
                    while true do
                        if PAD.IS_CONTROL_JUST_PRESSED(45, 45) then 
                            break
                        end
                        if raycast_coord[4] ~= 0 and ENTITY.GET_ENTITY_TYPE(raycast_coord[4]) >= 1 and ENTITY.GET_ENTITY_TYPE(raycast_coord[4]) < 3 then
                            ggc1 = ENTITY.GET_ENTITY_COORDS(raycast_coord[4], true)
                        else
                            ggc1 = raycast_coord[2]
                        end
                        local c2 = ENTITY.GET_ENTITY_COORDS(players.user_ped(), true)
                        local dist = MISC.GET_DISTANCE_BETWEEN_COORDS(ggc1['x'], ggc1['y'], ggc1['z'], c2['x'], c2['y'], c2['z'], true)
                        -- safety
                        if not lastdist or dist < lastdist then 
                            lastdist = dist
                        else
                            break
                        end
                        if ENTITY.IS_ENTITY_DEAD(players.user_ped()) then
                            break
                        end
                        if dist >= 10 then
                            local dir = {}
                            dir['x'] = (ggc1['x'] - c2['x']) * dist
                            dir['y'] = (ggc1['y'] - c2['y']) * dist
                            dir['z'] = (ggc1['z'] - c2['z']) * dist
                            --ENTITY.APPLY_FORCE_TO_ENTITY(players.user_ped(), 2, dir['x'], dir['y'], dir['z'], 0.0, 0.0, 0.0, 0, false, false, true, false, true)
                            ENTITY.SET_ENTITY_VELOCITY(players.user_ped(), dir['x'], dir['y'], dir['z'])
                        else
                            local t = ENTITY.GET_ENTITY_TYPE(raycast_coord[4])
                            if t == 2 then
                                set_player_into_suitable_seat(raycast_coord[4])
                            elseif t == 1 then
                                local v = PED.GET_VEHICLE_PED_IS_IN(t, false)
                                if v ~= 0 then
                                    set_player_into_suitable_seat(v)
                                end
                            end
                            break
                        end
                        util.yield()
                    end
                end
            end
        end
    end

    if paintball then
        ls_log("paintball loop")
        local ent = get_aim_info()['ent']
        request_control_of_entity(ent)
        if PED.IS_PED_SHOOTING(players.user_ped()) then
            if ENTITY.IS_ENTITY_A_VEHICLE(ent) then
                ls_log("paintball hit")
                rand = {}
                rand['r'] = math.random(100,255)
                rand['g'] = math.random(100,255)
                rand['b'] = math.random(100,255)
                VEHICLE.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(ent, rand['r'], rand['g'], rand['b'])
                VEHICLE.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(ent, rand['r'], rand['g'], rand['b'])
            end
        end
    end

    if aim_info then
        local info = get_aim_info()
        if info['ent'] ~= 0 then
            local text = "Hash: " .. info['hash'] .. "\nEntity: " .. info['ent'] .. "\nHealth: " .. info['health'] .. "\nType: " .. info['type'] .. "\nSpeed: " .. info['speed']
            directx.draw_text(0.5, 0.3, text, 5, 0.5, white, true)
        end
    end

    if gun_stealer then
        if PED.IS_PED_SHOOTING(players.user_ped()) then
            local ent = get_aim_info()['ent']
            if ENTITY.IS_ENTITY_A_VEHICLE(ent) then
                local driver = VEHICLE.GET_PED_IN_VEHICLE_SEAT(ent, -1)
                if PED.IS_PED_A_PLAYER(driver) then
                    hijack_veh_for_player(ent)
                end
                request_control_of_entity(ent)
                set_player_into_suitable_seat(ent)
            end
        end
    end

    if drivergun then
        local ent = get_aim_info()['ent']
        request_control_of_entity(ent)
        if PED.IS_PED_SHOOTING(players.user_ped()) then
            if ENTITY.IS_ENTITY_A_VEHICLE(ent) then
                local driver = VEHICLE.GET_PED_IN_VEHICLE_SEAT(ent, -1)
                if driver == 0 or not PED.IS_PED_A_PLAYER(driver) then
                    if not PED.IS_PED_A_PLAYER(driver) then
                        entities.delete(driver)
                    end
                    local hash = 0x9C9EFFD8
                    request_model_load(hash)
                    local coords = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(ent, -2.0, 0.0, 0.0)
                    coords.x = coords['x']
                    coords.y = coords['y']
                    coords.z = coords['z']
                    local ped = entities.create_ped(28, hash, coords, 30.0)
                    PED.SET_PED_INTO_VEHICLE(ped, ent, -1)
                    ENTITY.SET_ENTITY_INVINCIBLE(ped, true)
                    PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(ped, true)
                    PED.SET_PED_FLEE_ATTRIBUTES(ped, 0, false)
                    PED.SET_PED_COMBAT_ATTRIBUTES(ped, 46, true)
                    PED.SET_PED_CAN_BE_DRAGGED_OUT(ped, false)
                    PED.SET_PED_CAN_BE_KNOCKED_OFF_VEHICLE(ped, false)
                    TASK.TASK_VEHICLE_DRIVE_TO_COORD(ped, ent, math.random(1000), math.random(1000), math.random(100), 100, 1, ENTITY.GET_ENTITY_MODEL(ent), 4, 5, 0)
                end
            end
        end
    end

    if entgun then
        if PED.IS_PED_SHOOTING(players.user_ped()) then
            local hash = shootent
            request_model_load(hash)
            local c1 = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(players.user_ped(), 0.0, 5.0, 0.0)
            local res = raycast_gameplay_cam(-1, 1000.0)
            local dir = {}
            local c2 = {}
            if res[1] ~= 0 then
                c2 = res[2]
                dir['x'] = (c2['x'] - c1['x'])*1000
                dir['y'] = (c2['y'] - c1['y'])*1000
                dir['z'] = (c2['z'] - c1['z'])*1000
            else 
                c2 = get_offset_from_gameplay_camera(1000)
                dir['x'] = (c2['x'] - c1['x'])*1000
                dir['y'] = (c2['y'] - c1['y'])*1000
                dir['z'] = (c2['z'] - c1['z'])*1000
            end
            c1.x = c1['x']
            c1.y = c1['y']
            c1.z = c1['z']
            local ent = OBJECT.CREATE_OBJECT_NO_OFFSET(hash, c1['x'], c1['y'], c1['z'], true, false, false)
            ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(ent, players.user_ped(), false)
            ENTITY.APPLY_FORCE_TO_ENTITY(ent, 0, dir['x'], dir['y'], dir['z'], 0.0, 0.0, 0.0, 0, true, false, true, false, true)
            if not entgungrav then
                ENTITY.SET_ENTITY_HAS_GRAVITY(ent, false)
            end
            --ENTITY.SET_OBJECT_AS_NO_LONGER_NEEDED(ent)
        end
    end

    if tesla_ped ~= 0 then
        lastcar = PLAYER.GET_PLAYERS_LAST_VEHICLE()
        p_coords = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID(), true)
        t_coords = ENTITY.GET_ENTITY_COORDS(lastcar, true)
        dist = MISC.GET_DISTANCE_BETWEEN_COORDS(p_coords['x'], p_coords['y'], p_coords['z'], t_coords['x'], t_coords['y'], t_coords['z'], false)
        if lastcar == 0 or ENTITY.GET_ENTITY_HEALTH(lastcar) == 0 or dist <= 5 then
            entities.delete(tesla_ped)
            VEHICLE.BRING_VEHICLE_TO_HALT(lastcar, 5.0, 2, true)
            VEHICLE.SET_VEHICLE_DOORS_LOCKED_FOR_ALL_PLAYERS(lastcar, false)
            VEHICLE.START_VEHICLE_HORN(lastcar, 1000, util.joaat("NORMAL"), false)
            tesla_ped = 0
            util.remove_blip(tesla_blip)
        end
    end
    util.yield()
end

