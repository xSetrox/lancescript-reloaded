-- LANCESCRIPT RELOADED
util.require_natives("1640181023")
gta_labels = require('all_labels')
all_labels = gta_labels.all_labels
sexts = gta_labels.sexts
coded_for_gtao_version = 1.60
is_loading = true
ls_debug = false
all_vehicles = {}
all_objects = {}
all_players = {}
all_peds = {}
all_pickups = {}
handle_ptr = memory.alloc(13*8)
player_cur_car = 0
good_guns = {453432689, 171789620, 487013001, -1716189206, 1119849093}

-- log if verbose/debug mode is on
function ls_log(content)
    if ls_debug then
        util.toast(content)
        util.log("[LANCESCRIPT RELOADED] " .. content)
    end
end

-- check online version
online_v = tonumber(NETWORK._GET_ONLINE_VERSION())
if online_v > coded_for_gtao_version then
    util.toast("This script is outdated for the current GTA:O version (" .. online_v .. ", coded for " .. ocoded_for .. "). Some options may not work, but most should.")
end

-- filesystem handling and logo 
store_dir = filesystem.store_dir() .. '/lancescript_reloaded/'
resources_dir = filesystem.resources_dir() .. '/lancescript_reloaded/'
if not filesystem.is_dir(resources_dir) then
    util.toast("ALERT: resources dir is missing! Please make sure you installed Lancescript Reloaded properly.")
end

if not filesystem.is_dir(store_dir) then
    filesystem.mkdirs(store_dir)
end

lancescript_logo = directx.create_texture(resources_dir .. 'lancescript_logo.png')
-- logo display
if SCRIPT_MANUAL_START then
    AUDIO.PLAY_SOUND(-1, "Virus_Eradicated", "LESTER1A_SOUNDS", 0, 0, 1)
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
ls_log("Now setting up lists")
-- BEGIN SELF SUBSECTIONS
self_root = menu.list(menu.my_root(), "Me", {"lancescriptself"}, "Lets you do things to your ped, your combat, and your vehicle")
my_vehicle_root = menu.list(self_root, "My vehicle", {"lancescriptmyvehicle"}, "Lets you do things to your active vehicle")
combat_root = menu.list(self_root, "My combat/weapons", {"lancescriptcombat"}, "Combat/weapon-related options")
-- END SELF SUBSECTIONS
-- BEGIN ONLINE SUBSECTIONS
online_root = menu.list(menu.my_root(), "Online", {"lancescriptonline"}, "Online")

local players_shortcut_command = menu.ref_by_path('Players', 37)
menu.action(menu.my_root(), "Players shortcut", {}, "Quickly opens session players list, for convenience", function(on_click)
    menu.trigger_command(players_shortcut_command)
end)

ap_root = menu.list(online_root, "All players", {"lancescriptonline"}, "Players")
apfriendly_root = menu.list(ap_root, "friendly", {"apfriendly"}, "")
aphostile_root = menu.list(ap_root, "Hostile", {"aphostile"}, "")
apneutral_root = menu.list(ap_root, "Neutral", {"apneutral"}, "")
ap_texts_root = menu.list(apneutral_root, "Texts", {"aptexts"}, "")
ap_vaddons = menu.list(apfriendly_root, "Vehicle addons", {"lsvaddons"}, "")
-- END ONLINE SUBSECTIONS
-- BEGIN ENTITIES SUBSECTION
entities_root = menu.list(menu.my_root(), "Entities", {"lancescriptentities"}, "Peds, vehicles you aren\'t in, and pickups")
peds_root = menu.list(entities_root, "Peds", {"lancescriptpeds"}, "Pedestrian-related fuckery")
vehicles_root = menu.list(entities_root, "Vehicles", {"lancescriptvehicles"}, "Vehicle-related fuckery")
pickups_root = menu.list(entities_root, "Pickups", {"lancescriptpickups"}, "Pickup-related fuckery")
-- END ENTITIES SUBSECTION
world_root = menu.list(menu.my_root(), "World", {"lancescriptworld"}, "World options")
tweaks_root = menu.list(menu.my_root(), "Game tweaks", {"lancescriptpickups"}, "Tweaks to pimp out your game")
lancescript_root = menu.list(menu.my_root(), "Misc", {"lancescriptoptions"}, "")
async_http.init("pastebin.com", "/raw/nrMdhHwE", function(result)
    menu.hyperlink(menu.my_root(), "Join discord", result, "")
end)
async_http.dispatch()

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

function hasValue( tbl, str )
    local f = false
    for i = 1, #tbl do
        if type( tbl[i] ) == "table" then
            f = hasValue( tbl[i], str )  --  return value from recursion
            if f then break end  --  if it returned true, break out of loop
        elseif tbl[i] == str then
            return true
        end
    end
    return f
end

function pid_to_handle(pid)
    NETWORK.NETWORK_HANDLE_FROM_PLAYER(pid, handle_ptr, 13)
    return handle_ptr
end

function get_model_size(hash)
    ls_log("Getting model size of hash " .. hash)
    ls_log("alloc 24 bytes, modelsize minptr")
    local minptr = memory.alloc(24)
    ls_log("alloc 24 bytes, modelsize maxptr")
    local maxptr = memory.alloc(24)
    MISC.GET_MODEL_DIMENSIONS(hash, minptr, maxptr)
    min = memory.read_vector3(minptr)
    max = memory.read_vector3(maxptr)
    local size = {}
    size['x'] = max['x'] - min['x']
    size['y'] = max['y'] - min['y']
    size['z'] = max['z'] - min['z']
    size['max'] = math.max(size['x'], size['y'], size['z'])
    ls_log("Got model size of hash, it was " .. size['x'] .. " " .. size['y'] .. " " .. size['z'])
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
    ls_log("raycast gameplay cam, allocating")
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
            -1, 
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
    ls_log("raycast cam, allocating")
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
    ls_log("Setting player into suitable seat of entity " .. ent)
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
local ent_types = {"None", "Ped", "Vehicle", "Object"}
function get_aim_info()
    ls_log("alloc 4 bytes, get_aim_info")
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
    ls_log("Kicking " .. pid .. " from vehicle.")
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
                util.toast("Failed to free car seat in 10 seconds")
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
        util.toast("Vehicle jack complete!")
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
        ls_log("Requesting entity control of " .. ent)
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
            ls_log("Got ground Z successfully: " .. est)
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
menu.toggle(self_root, "Walk on water", {"walkonwater"}, "no blasphemy permitted! this will not function when you are inside a vehicle.", function(on)
    walkonwater = on
    if on then
        menu.set_value(ls_driveonair, false)
    end
end)


menu.action(self_root, "Set/unset custom ped flag", {"custompedflag"}, "Do not touch unless you know what you\'re doing. I mean you do you but if it crashes your game I don\'t wanna hear it.", function(on_click)
    util.toast("Please input the flag int to use")
    menu.show_command_box("custompedflag ")
end, function(on_command)
    local pflag = tonumber(on_command)
    if ped_flags[pflag] == true then
        ped_flags[pflag] = false
        util.toast("Flag set to false")
    else
        ped_flags[pflag] = true
        util.toast("Flag set to true")
    end
end)

menu.toggle(self_root, "Burning man", {"burningman"}, "Walk da fire (turn off all godmode/auto-heal options first or this wont work)", function(on)
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
my_vehicle_movement_root = menu.list(my_vehicle_root, "Movement", {"myvehmovement"}, "Movement-related options for your vehicle.")

speedometer_plate_root = menu.list(my_vehicle_root, "Speedometer plate", {"lancescriptmyvehicle"}, "Lets you do things to your active vehicle")
mph_plate = false
menu.toggle(speedometer_plate_root, "Speedometer plate", {"speedplate"}, "Sets your plate to your speed, constantly.", function(on)
    mph_plate = on
    if on then
        if player_cur_car ~= 0 then
            original_plate = VEHICLE.GET_VEHICLE_NUMBER_PLATE_TEXT(player_cur_car)
        else
            util.toast("You were not in a vehicle when starting this. You won\'t be able to revert plate text.")
            original_plate = "LANCE"
        end
    else
        if player_cur_car ~= 0 then
            if original_plate == nil then
                original_plate = "LANCE"
            end
            VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(player_cur_car, original_plate)
        end
    end
end)

mph_unit = "kph"
menu.toggle(speedometer_plate_root, "Use MPH for speedometer plate", {"usemph"}, "Toggle off if you aren\'t American.", function(on)
    mph_unit = if on then "mph" else "kph"
end, false)

-- BEGIN MOVEMENT ROOT
dow_block = 0
driveonwater = false
local ls_driveonwater = menu.toggle(my_vehicle_movement_root, "Drive on water", {"driveonwater"}, "why does everyone need this feature!!!!!!!!", function(on)
    driveonwater = on
    if on then
        if driveonair then
            menu.set_value(ls_driveonair, false)
            util.toast("Drive on air has been turned OFF automatically to prevent issues.")
        end
    else
        if not driveonair and not walkonwater then
            ENTITY.SET_ENTITY_COORDS_NO_OFFSET(dow_block, 0, 0, 0, false, false, false)
        end
    end
end)

doa_ht = 0
driveonair = false
ls_driveonair = menu.toggle(my_vehicle_movement_root, "Drive on air", {"driveonair"}, "yes", function(on)
    driveonair = on
    if on then
        local pos = ENTITY.GET_ENTITY_COORDS(players.user_ped(), true)
        doa_ht = pos['z']
        util.toast("Use space and ctrl to fine-tune your driving height!")
        if driveonwater then
            menu.trigger_commands("driveonwater off")
            util.toast("Drive on water has been turned OFF automatically to prevent issues.")
        end
    end
end)

menu.toggle_loop(my_vehicle_movement_root, "Vehicle strafe", {"vstrafe"}, "Use right and left arrow keys to make your vehicle strafe horizontally.", function(toggle)
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
menu.toggle_loop(my_vehicle_movement_root, "Vehicle jump", {"vjump"}, "Lets you jump with any vehicle with horn", function(toggle)
    if player_cur_car ~= 0 then
        if PAD.IS_CONTROL_JUST_PRESSED(86,86) then
            ENTITY.APPLY_FORCE_TO_ENTITY(player_cur_car, 1, 0.0, 0.0, vjumpforce, 0.0, 0.0, 0.0, 0, true, true, true, false, true)
        end
    end
end)

menu.toggle_loop(my_vehicle_movement_root, "Vehicle slam", {"vslam"}, "The opposite of vehicle jump, thrusts your vehicle back toward the ground.", function(toggle)
    ls_log("vslam")
    if player_cur_car ~= 0 then
        if PAD.IS_CONTROL_JUST_PRESSED(36,36) then
            ENTITY.APPLY_FORCE_TO_ENTITY(player_cur_car, 1, 0.0, 0.0, -vslamforce, 0.0, 0.0, 0.0, 0, true, true, true, false, true)
        end
    end
end)


menu.slider(my_vehicle_movement_root, "Vehicle jump force", {"vjumpforce"}, "", 1, 300, 20, 1, function(s)
    vjumpforce = s
  end)


menu.slider(my_vehicle_movement_root, "Vehicle slam force", {"vslamforce"}, "", 1, 300, 50, 1, function(s)
    vslamforce = s
  end)

menu.toggle_loop(my_vehicle_movement_root, "Stick to ground/walls", {"stick2ground"}, "Keeps your car on the ground (may sacrifice performance due to friction, duhh). If riding walls is what ye seek, this also does that.", function(on)
    if player_cur_car ~= 0 then
        local vel = ENTITY.GET_ENTITY_VELOCITY(player_cur_car)
        vel['z'] = -vel['z']
        ENTITY.APPLY_FORCE_TO_ENTITY(player_cur_car, 2, 0, 0, -50 -vel['z'], 0, 0, 0, 0, true, false, true, false, true)
        --ENTITY.SET_ENTITY_VELOCITY(player_cur_car, vel['x'], vel['y'], -0.2)
    end
end)

menu.action(my_vehicle_movement_root, "Vehicle 180", {"vehicle180"}, "Turns your vehicle around with momentum preserved. Recommended to bind this.", function(on_click)
    if player_cur_car ~= 0 then
        local rot = ENTITY.GET_ENTITY_ROTATION(player_cur_car, 0)
        local vel = ENTITY.GET_ENTITY_VELOCITY(player_cur_car)
        ENTITY.SET_ENTITY_ROTATION(player_cur_car, rot['x'], rot['y'], rot['z']+180, 0, true)
        ENTITY.SET_ENTITY_VELOCITY(player_cur_car, -vel['x'], -vel['y'], vel['z'])
    end
end)

v_f_previous_car = 0
fly_speed = 10
v_fly = false
v_f_plane = 0
local ls_vehiclefly = menu.toggle(my_vehicle_movement_root, "Vehicle fly", {"vehiclefly"}, "Makes your vehicle fly. Flies just like a plane.. suspicious really.", function(on)
    if on then
        if player_cur_car == 0 then
            util.toast("You are not in a car. Enter a car before enabling this.")
            menu.set_value(ls_vehiclefly, false)
        else
            v_fly = true
            v_f_previous_car = player_cur_car
            local vehicle_model = util.joaat("alphaz1")
            request_model_load(vehicle_model)
            local c = ENTITY.GET_ENTITY_COORDS(player_cur_car, false)
            v_f_plane = entities.create_vehicle(vehicle_model, c, ENTITY.GET_ENTITY_HEADING(player_cur_car))
            local angs = ENTITY.GET_ENTITY_ROTATION(v_f_previous_car, 0)
            ENTITY.SET_ENTITY_ROTATION(v_f_plane, angs.x, angs.y, angs.z, 0, true)
            local vehicle_vel = ENTITY.GET_ENTITY_VELOCITY(v_f_previous_car)
            ENTITY.SET_ENTITY_VELOCITY(v_f_plane, vehicle_vel.x, vehicle_vel.y, vehicle_vel.z)
            ENTITY.SET_ENTITY_INVINCIBLE(v_f_plane, true)
            AUDIO._FORCE_VEHICLE_ENGINE_AUDIO(v_f_plane, "ADDER")
            ENTITY.ATTACH_ENTITY_TO_ENTITY(v_f_previous_car, v_f_plane, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 0, true)
            ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(obj, false, true)
            ENTITY.SET_ENTITY_ALPHA(v_f_plane, 0)
            PED.SET_PED_INTO_VEHICLE(players.user_ped(), v_f_plane, -1)
            VEHICLE.SET_HELI_BLADES_FULL_SPEED(v_f_plane)
        end
    else
        if v_f_previous_car ~= 0 then
            PED.SET_PED_INTO_VEHICLE(players.user_ped(), v_f_previous_car, -1)
            ENTITY.DETACH_ENTITY(v_f_previous_car, true, true)
            -- sometimes runs if the plane doesnt exist??
            if v_f_plane ~= 0 then
                entities.delete(v_f_plane)
            end
            v_fly = false
        end
    end
end)

-- END MOVEMENT ROOT

menu.action(my_vehicle_root, "Force leave vehicle", {"forceleaveveh"}, "Force leave vehicle, in case of emergency or stuckedness", function(on_click)
    TASK.CLEAR_PED_TASKS_IMMEDIATELY(players.user_ped())
    TASK.TASK_LEAVE_ANY_VEHICLE(players.user_ped(), 0, 16)
end)

cinematic_autod = false
menu.toggle(my_vehicle_root, "Cinematic auto-drive", {"cinematicautodrive"}, "Automatically navigates you to your waypoint while in cinematic camera mode, like in red dead redemption.", function(on)
    cinematic_autod = on
end)

menu.action(my_vehicle_root, "Break rudder", {"breakrudder"}, "Breaks rudder. Good for stunts. Useless if you don\'t have an aircraft lol.", function(on_click)
    if player_cur_car ~= 0 then
        VEHICLE.SET_VEHICLE_RUDDER_BROKEN(player_cur_car, true)
    end
end)

menu.toggle_loop(my_vehicle_root, "Force spawn countermeasures", {"forcecms"}, "Forces countermeasures out in any vehicle when you use the horn key", function(on)
    if PAD.IS_CONTROL_PRESSED(46, 46) then
        local target = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(players.user_ped(), math.random(-5, 5), -30.0, math.random(-5, 5))
        --MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(target['x'], target['y'], target['z'], target['x'], target['y'], target['z'], 300.0, true, -1355376991, players.user_ped(), true, false, 100.0)
        MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(target['x'], target['y'], target['z'], target['x'], target['y'], target['z'], 100.0, true, 1198879012, players.user_ped(), true, false, 100.0)
    end
end)

menu.toggle_loop(my_vehicle_root, "Render scorched", {"renderscorched"}, "Renders your car scorched.", function(on)
    if player_cur_car ~= 0 then
        ENTITY.SET_ENTITY_RENDER_SCORCHED(player_cur_car, true)
    end
end, function(on_stop)
    if player_cur_car ~= 0 then
        ENTITY.SET_ENTITY_RENDER_SCORCHED(player_cur_car, false)
    end
end)

tesla_ped = 0
menu.action(my_vehicle_root, "Tesla summon", {"teslasummon"}, "Have your car drive itself to you. Breaks a lot for multiple reasons but it was too fun to scrap.", function(on_click)
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


menu.toggle_loop(my_vehicle_movement_root, "Hold shift to drift", {"shiftdrift"}, "You heard me.", function(on)
    if PAD.IS_CONTROL_PRESSED(21, 21) then
        VEHICLE.SET_VEHICLE_REDUCE_GRIP(player_cur_car, true)
        VEHICLE._SET_VEHICLE_REDUCE_TRACTION(player_cur_car, 0.0)
    else
        VEHICLE.SET_VEHICLE_REDUCE_GRIP(player_cur_car, false)
    end
end)

menu.toggle_loop(my_vehicle_movement_root, "Horn boost", {"hornboost"}, "beeeeeeeeeeeeeeeeeeeeeeeeeep", function(on)
    if player_cur_car ~= 0 then
        ls_log("horn boost")
        VEHICLE.SET_VEHICLE_ALARM(player_cur_car, false)
        if AUDIO.IS_HORN_ACTIVE(player_cur_car) then
            ENTITY.APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(player_cur_car, 1, 0.0, 1.0, 0.0, true, true, true, true)
        end
    end
end)


-- COMBAT
-- COMBAT-RELATED toggles, actions, and functionality

-- ## silent aimbot
silent_aimbotroot = menu.list(combat_root, "Silent aimbot", {"lancescriptaimbot"}, "A custom, discreet aimbot that is nowhere near as noticeable as a traditional aimbot.")
kill_auraroot = menu.list(combat_root, "Kill aura", {"lancescriptkillaura"}, "Kills anyone too close to you. Exactly like hacked Minecraft clients.")
weapons_root = menu.list(combat_root, "Special weapons", {"lancescriptspecialweapons"}, "Special, unique weapons and weapon modes")

kill_aura = false
menu.toggle(kill_auraroot, "Kill aura", {"killaura"}, "Kills anyone too close to you. Exactly like hacked Minecraft clients.", function(on)
    kill_aura = on
    mod_uses("ped", if on then 1 else -1)
end)

kill_aura_peds = false
menu.toggle(kill_auraroot, "Kill peds", {"killaurapeds"}, "", function(on)
    kill_aura_peds = on
end)

kill_aura_players = false
menu.toggle(kill_auraroot, "Kill players", {"killauraplayers"}, "", function(on)
    kill_aura_players = on
end)

kill_aura_friends = false
menu.toggle(kill_auraroot, "Target friends", {"killaurafriends"}, "", function(on)
    kill_aura_friends= on
end)


kill_aura_dist = 20
menu.slider(kill_auraroot, "Kill aura radius", {"killauraradius"}, "", 1, 100, 20, 1, function(s)
    kill_aura_dist = s
end)


-- entity gun
entity_gun = menu.list(weapons_root, "Entity gun", {"lancescriptentgun"}, "Shoot entities.")
entgun = false
shootent = -422877666
menu.toggle(entity_gun, "Entity gun", {"entgun"}, "Shoot them entities", function(on)
    entgun = on
end, false)

menu.action(entity_gun, "Dildo (default)", {"shootentdildo"}, "Click to choose this entity to fire", function(on_click)
    shootent = -422877666
    util.toast("You will now shoot this entity")
end)

menu.action(entity_gun, "Soccer ball", {"shootentsoccer"}, "Click to choose this entity to fire", function(on_click)
    shootent = -717142483
    util.toast("You will now shoot this entity")
end)

menu.action(entity_gun, "Bucket", {"shootentbucket"}, "Click to choose this entity to fire", function(on_click)
    shootent = util.joaat("prop_paints_can07")
    util.toast("You will now shoot this entity")
end)

entgungrav = false
menu.toggle(entity_gun, "Entity gun gravity", {"entgungravity"}, "", function(on)
    entgungrav = on
end, false)


menu.action(entity_gun, "Custom obj model", {"customentgunmodel"}, "Input a custom model to shoot. The model name, not the hash.", function(on_click)
    util.toast("Please input the model name")
    menu.show_command_box("customentgunmodel" .. " ")
end, function(on_command)
    local hash = util.joaat(on_command)
    if not STREAMING.IS_MODEL_VALID(hash) then
        util.toast("That was an invalid model.")
    else
        shootent = hash
        util.toast("Entity gun has been set to shoot " .. on_command)
    end
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
menu.toggle_loop(silent_aimbotroot, "Silent aimbot", {"saimbottoggle"}, "Turn silent aimbot on/off", function(toggle)
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

menu.toggle(silent_aimbotroot, "Silent aimbot players", {"saimbotplayers"}, "", function(on)
    satarget_players = on
end)

menu.toggle(silent_aimbotroot, "Silent aimbot NPC\'s", {"saimbotpeds"}, "", function(on)
    satarget_npcs = on
end)

menu.toggle(silent_aimbotroot, "Use FOV", {"saimbotusefov"}, "Most accurate in first-person for really small FOV values. Usually it won\'t really matter though.", function(on)
    satarget_usefov = on
end, true)

sa_fov = 60
menu.slider(silent_aimbotroot, "FOV", {"saimbotfov"}, "", 1, 270, 60, 1, function(s)
    sa_fov = s
end)

menu.toggle(silent_aimbotroot, "Ignore targets inside vehicles", {"saimbotnovehicles"}, "If you want to be more realistic, or are having issues hitting targets in vehicles", function(on)
    satarget_novehicles = on
end)

satarget_nogodmode = true
menu.toggle(silent_aimbotroot, "Ignore godmoded targets", {"saimbotnogodmodes"}, "Because what\'s the point?", function(on)
    satarget_nogodmode = on
end, true)

menu.toggle(silent_aimbotroot, "Target friends", {"saimbottargetfriends"}, "", function(on)
    satarget_targetfriends = on
end)

menu.toggle(silent_aimbotroot, "Damage override", {"saimbotdmgo"}, "", function(on)
    satarget_damageo = on
end)

sa_odmg = 100
menu.slider(silent_aimbotroot, "Damage override amount", {"saimbotdamageoverride"}, "", 1, 1000, 100, 1, function(s)
    sa_odmg = s
end)

menu.toggle(silent_aimbotroot, "Display target", {"saimbotshowtarget"}, "Whether or not to draw an AR beacon on who your aimbot will hit.", function(on)
    sa_showtarget = on
end, true)
--

local start_tint
local cur_tint
menu.toggle_loop(weapons_root, "Rainbow weapon tint", {"rainbowtint"}, "boogie", function()
    local plyr = players.user_ped()
    if start_tint == nil then
        start_tint = WEAPON.GET_PED_WEAPON_TINT_INDEX(plyr, WEAPON.GET_SELECTED_PED_WEAPON(plyr))
        cur_tint = start_tint
        cur_tint = if cur_tint == 8 then 0 else cur_tint + 1
        WEAPON.SET_PED_WEAPON_TINT_INDEX(plyr,WEAPON.GET_SELECTED_PED_WEAPON(plyr), cur_tint)
        util.yield(50)
    end
end, function()
        WEAPON.SET_PED_WEAPON_TINT_INDEX(players.user_ped(),WEAPON.GET_SELECTED_PED_WEAPON(players.user_ped()), start_tint)
        start_tint = nil
end)

menu.toggle(weapons_root, "Invisible weapons", {"invisguns"}, "Makes your weapons invisible. Might be local only. You need to retoggle when switching weapons.", function(on)
    local plyr = players.user_ped()
    WEAPON.SET_PED_CURRENT_WEAPON_VISIBLE(plyr, not on, false, false, false) 
end)

aim_info = false
menu.toggle(weapons_root, "Aim info", {"aiminfo"}, "Displays info of the entity you\'re aiming at", function(on)
    aim_info = on
end)

gun_stealer = false
menu.toggle(weapons_root, "Car stealer gun", {"gunstealer"}, "Shoot a vehicle to steal it. If it is a car with a player driver, it will teleport you into the next available seat.", function(on)
    gun_stealer = on
end)

paintball = false
menu.toggle(weapons_root, "Paintball", {"paintball"}, "Shoot a vehicle and it will turn into a random color! You may have to shoot a few times if in online due to entity ownership.", function(on)
    paintball = on
end)

drivergun = false
menu.toggle(weapons_root, "NPC driver gun", {"drivergun"}, "Shoot a vehicle to insert an NPC driver that will drive the vehicle to a random area. You may have to shoot a few times if in online due to entity ownership.", function(on)
    drivergun = on
end)

grapplegun = false
menu.toggle(weapons_root, "Grapple gun", {"grapplegun"}, "fun stuff", function(on)
    grapplegun = on
    if on then
        WEAPON.GIVE_WEAPON_TO_PED(players.user_ped(), util.joaat('weapon_pistol'), 9999, false, false)
        util.toast("Grapple gun is now active! Shoot somewhere with a pistol. Press R while grappling to stop grappling.")
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

                    if php_bars then
                        local d_coord = ENTITY.GET_ENTITY_COORDS(ped, true)
                        d_coord['z'] = d_coord['z'] + 0.8
                        local hp = ENTITY.GET_ENTITY_HEALTH(ped)
                        local perc = hp/ENTITY.GET_ENTITY_MAX_HEALTH(ped)*100
                        if perc ~= 0 then
                            local r = 0
                            local g = 0
                            local b = 0
                            if perc == 100 then
                                r = 0
                                g = 255
                                b = 0
                            elseif perc < 100 and perc > 50 then
                                r = 255
                                g = 255
                                b = 0
                            else
                                r = 255
                                g = 0
                                b = 0
                            end
                            GRAPHICS.DRAW_MARKER(43, d_coord['x'], d_coord['y'], d_coord['z'], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.10, 0, perc/150, r, g, b, 100, false, true, 2, false, 0, 0, false)
                        end
                    end

                    if allpeds_gun ~= 0 then
                        WEAPON.GIVE_WEAPON_TO_PED(ped, allpeds_gun, 9999, false, false)
                    end

                    -- ONLINE INTERACTIONS
                    if ped_chase then
                        if PED.IS_PED_IN_ANY_VEHICLE(ped) then
                            PED.SET_PED_COMBAT_ATTRIBUTES(ped, 5, true)
                            PED.SET_PED_COMBAT_ATTRIBUTES(ped, 46, true)
                            TASK.SET_TASK_VEHICLE_CHASE_IDEAL_PURSUIT_DISTANCE(ped, 0.0)
                            TASK.SET_TASK_VEHICLE_CHASE_BEHAVIOR_FLAG(ped, 1, true)
                            TASK.TASK_COMBAT_PED(ped, chase_target, 0, 16)
                            TASK.TASK_VEHICLE_CHASE(ped, PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(chase_target))
                        end
                    end
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
ped_b_root = menu.list(peds_root, "Behavior", {"lancescriptpedbehavior"}, "Pedestrian-related behavior fuckery")
tasks_root = menu.list(peds_root, "Tasks", {"lancescriptpedtasks"}, "Pedestrian-related tasks fuckery")
ped_voice = menu.list(peds_root, "Voice", {"lancescriptpedaudio"}, "Pedestrian-related voice fuckery")
spawn_peds_root = menu.list(peds_root, "Spawn", {"lancescriptspawnpeds"}, "Spawn them")
ped_extras = menu.list(peds_root, "Extras", {"lancescriptpedextras"}, "Pedestrian-related extra options")

-- SPAWNING PEDS
num_peds_spawn = 1
function spawn_ped(hash)
    coords = ENTITY.GET_ENTITY_COORDS(players.user_ped(), false)
    coords.x = coords['x']
    coords.y = coords['y']
    coords.z = coords['z']
    request_model_load(hash)
    for i=1, num_peds_spawn do
        entities.create_ped(28, hash, coords, math.random(0, 270))
    end
end

spawn_animals_root = menu.list(spawn_peds_root, "Animals", {"lancescriptspawnpedsanimals"}, "Spawn them")


menu.action(spawn_peds_root, "Input hash", {"inputpedspawnhash"}, "Spawn whatever you want", function(on_click)
    util.toast("Please input the model hash (should be a string)")
    menu.show_command_box("inputpedspawnhash ")
end, function(on_command)
    spawn_ped(util.joaat(on_command))
end)


menu.slider(spawn_peds_root, "Spawn count", {"pedspawnct"}, "Choose wisely", 1, 10, 1, 1, function(s)
    num_peds_spawn = s
end)

menu.action(spawn_animals_root, "Rat", {"spawnpedrat"}, "", function(on_click)
    spawn_ped(-1011537562)
end)

menu.action(spawn_animals_root, "Fish", {"spawnpedfish"}, "", function(on_click)
    spawn_ped(802685111)
end)

menu.action(spawn_animals_root, "Stingray", {"spawnpedfish"}, "", function(on_click)
    spawn_ped(-1589092019)
end)

menu.action(spawn_animals_root, "Hen", {"spawnpedhen"}, "", function(on_click)
    spawn_ped(1794449327)
end)

menu.action(spawn_animals_root, "Deer", {"spawnpedhen"}, "", function(on_click)
    spawn_ped(-664053099)
end)

menu.action(spawn_animals_root, "Killer Whale", {"spawnpedkillerwhale"}, "", function(on_click)
    spawn_ped(-1920284487)
end)

---1011537562


allpeds_gun = 0
local ls_givepedswep = menu.click_slider(peds_root, "Gun to give to all peds", {"givepedswep"}, "0 = none\n1 = pistol\n2 = combat pdw\n3 = shotgun\n4 = Knife\n5 = minigun", 0, 5, 0, 1, function(s)
    if s == 0 then
        allpeds_gun = 0
    else
        allpeds_gun = good_guns[s]
    end
end)

menu.action(peds_root, "Teleport all to me", {"tpallpedshere"}, "", function(on_click)
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

menu.set_value(ls_givepedswep, 0)

function task_handler(type)
    -- whatever, just get it once this frame
    all_peds = entities.get_all_peds_as_handles()
    player_ped = PLAYER.PLAYER_PED_ID()
    for k,ped in pairs(all_peds) do
        if not PED.IS_PED_A_PLAYER(ped) then
            if type == "flop" then
                TASK.TASK_SKY_DIVE(ped)
            elseif type == "cover" then
                TASK.TASK_STAY_IN_COVER(ped)
            elseif type == "writheme" then
                TASK.TASK_WRITHE(ped, player_ped, -1, 0)
            elseif type == "vault" then
                TASK.TASK_CLIMB(ped, true)
            elseif type =="unused" then
                --
            elseif type == "cower" then
                TASK.TASK_COWER(ped, -1)
            end

        end
    end

end
menu.action(tasks_root, "Do the FLOP", {"flop"}, "All walking NPC\'s will do the flop. All driving NPC\'s will gently park their car, leave it, and do it then.", function(on_click)
    task_handler("flop")
end)

menu.action(tasks_root, "Move to cover", {"cover"}, "Pussy peds", function(on_click)
    task_handler("cover")
end)

menu.action(tasks_root, "Vault", {"vault"}, "They vault/skip over an invisible hurdle. Olympics. It also makes drivers vault out of their vehicle and fall through the world, because rockstar.", function(on_click)
    task_handler("vault")
end)

menu.action(tasks_root, "Cower", {"cower"}, "They cower for an eternity.", function(on_click)
    task_handler("cower")
end)


menu.action(tasks_root, "Writhe me", {"writheme"}, "Makes peds infinitely suffer on the ground. Finally a use for those dumbasses. The native makes drivers become invisible until they die for some reason.", function(on_click)
    task_handler("writheme")
end)

php_bars = false
menu.toggle(ped_extras, "HP bars", {"pedhpbars"}, "Draw health bars on NPC\'s.", function(on)
    php_bars = on
    mod_uses("ped", if on then 1 else -1)
    if vhp_bars and on then
        util.toast("WARNING: You have vehicle HP bars on at the same time as this! Some bars may not appear due to engine limits.")
    end
end)

peds_ignore = false
menu.toggle(ped_b_root, "Oblivious peds", {"obliviouspeds"}, "Peds will not care about anything you do. Peds already reacting to you will not forget what you did though.", function(on)
    peds_ignore = on
    mod_uses("ped", if on then 1 else -1)
end)

wantthesmoke = false
menu.toggle(ped_b_root, "Peds attack me", {"iwantthesmoke"}, "Tells all nearby peds you want the smoke. May break some things.", function(on)
    wantthesmoke = on
    mod_uses("ped", if on then 1 else -1)
end)

make_peds_cops = false
menu.toggle(ped_b_root, "Make nearby peds cops", {"makecops"}, "They\'re not actually real cops, but kind of are. They seem to flee very easily, but will snitch on you. Sort of like mall cops.", function(on)
    make_peds_cops = on
    mod_uses("ped", if on then 1 else -1)
end)

menu.toggle(ped_b_root, "Detroit", {"detroit"}, "All nearby NPC\'s duel it out and are given weapons. Recent developments show that this joke is considered insensitive, which is funny because more energy is spent ranting about it on Twitter than trying to fix crime in Detroit.", function(on)
    MISC.SET_RIOT_MODE_ENABLED(on)
end)

roast_voicelines = false
menu.toggle(ped_voice, "Roast voicelines", {"npcroasts"}, "Very unethical.", function(on)
    roast_voicelines = on
    mod_uses("ped", if on then 1 else -1)
end)

sex_voicelines = false
menu.toggle(ped_voice, "Sex voicelines", {"sexlines"}, "oH FuCK YeAh", function(on)
    sex_voicelines = on
    mod_uses("ped", if on then 1 else -1)
end)

gluck_voicelines = false
menu.toggle(ped_voice, "Gluck gluck 9000 voicelines", {"gluckgluck9000"}, "I\'m begging you, touch some grass.", function(on)
    gluck_voicelines = on
    mod_uses("ped", if on then 1 else -1)
end)

screamall = false
menu.toggle(ped_voice, "Scream", {"screamall"}, "Makes all nearby peds scream horrifically. Awesome.", function(on)
    screamall = on
    mod_uses("ped", if on then 1 else -1)
end)

-- VEHICLES

custom_rgb = false
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

v_phys_root = menu.list(vehicles_root, "Vehicle physics", {"lancescriptvphysics"}, "Control vehicle physics/launch them and shit")
vc_root = menu.list(v_phys_root, "Vehicle chaos", {"lancescriptchaos"}, "The day of reckoning")
v_traffic_root = menu.list(vehicles_root, "Vehicle traffic", {"lancescripttraffic"}, "Control vehicle traffic")
colorizev_root = menu.list(vehicles_root, "Color vehicles", {"lancescriptcolorize"}, "Paint all nearby vehicles colors!")

custom_r = 254
local ls_colorizecustomg = menu.slider(colorizev_root, "Custom R", {"colorizecustomr"}, "", 1, 255, 2, 1, function(s)
    custom_r = s
end)

custom_g = 2
local ls_colorizecustomg = menu.slider(colorizev_root, "Custom G", {"colorizecustomg"}, "", 1, 255, 2, 1, function(s)
    custom_g = s
end)

custom_b = 252
local ls_colorizecustomb = menu.slider(colorizev_root, "Custom B", {"colorizecustomb"}, "", 1, 255, 252, 1, function(s)
    custom_b = s
end)

menu.action(colorizev_root, "RGB preset: Stand magenta", {"rpstandmagenta"}, "g", function(on_click)
    menu.set_value(ls_colorizecustomr, 254)
    menu.set_value(ls_colorizecustomg, 2)
    menu.set_value(ls_colorizecustomb, 252)
end)

vehicle_chaos = false
menu.toggle(vc_root, "Vehicle chaos", {"chaos"}, "Enables the chaos...", function(on)
    vehicle_chaos = on
    mod_uses("vehicle", if on then 1 else -1)
end, false)

vc_gravity = true
menu.toggle(vc_root, "Vehicle chaos gravity", {"chaosgravity"}, "Gravity on/off", function(on)
    vc_gravity = on
end, true)

vc_speed = 100
menu.slider(vc_root, "Vehicle chaos speed", {"chaosspeed"}, "The speed to force the vehicles to. Higher = more chaos.", 30, 300, 100, 10, function(s)
  vc_speed = s
end)

--colorize_cars = false
local ls_colorizevehicles = menu.toggle(colorizev_root, "Colorize vehicles", {"colorizevehicles"}, "Colorizes all nearby vehicles with the valus you set! Turn on rainbow to RGB this ;", function(on)
    colorize_cars = on
    custom_rgb = on
    mod_uses("vehicle", if on then 1 else -1)
end)

menu.toggle(colorizev_root, "Rainbow", {"rainbowvehicles"}, "Requires colorize vehicles to be turned on.", function(on)
    if not colorize_cars then
        menu.set_value(ls_colorizevehicles, true)
    end
    custom_rgb = not on
end)


vhp_bars = false
menu.toggle(vehicles_root, "Vehicle HP bars", {"vehhpbars"}, "Draw health bars on vehicles.", function(on)
    vhp_bars = on
    mod_uses("vehicle", if on then 1 else -1)
    if php_bars and on then
        util.toast("WARNING: You have NPC HP bars on at the same time as this! Some bars may not appear due to engine limits.")
    end
end)

ascend_vehicles = false
menu.toggle(v_phys_root, "Ascend all nearby vehicles", {"ascendvehicles"}, "It\'s supposed to neatly make them levitate.. but it just sends them spinning in mid air. Which is fucking hilarious.", function(on)
    ascend_vehicles = on
    mod_uses("vehicle", if on then 1 else -1)
end)

blackhole = false
menu.toggle(v_phys_root, "Vehicle blackhole", {"blackhole"}, "A SUPER laggy but fun blackhole. When you toggle it on, it will set the blackhole position above you. Retoggle it to change the position. Oh also, this is very resource taxing and may temporarily fuck up collisions.", function(on)
    blackhole = on
    mod_uses("vehicle", if on then 1 else -1)
    if on then
        holecoords = ENTITY.GET_ENTITY_COORDS(players.user_ped(), true)
        util.toast("Blackhole position has been set 50 units above your position. Retoggle this on and off to change the position.")
    end
end)

hole_zoff = 50
menu.slider(v_phys_root, "Blackhole Z-offset", {"blackholeoffset"}, "How far above you to place the blackhole. Recommended to keep this fairly high.", 0, 100, 50, 10, function(s)
    hole_zoff = s
  end)


beep_cars = false
menu.toggle(vehicles_root, "Infinite horn on all nearby vehicles", {"beepvehicles"}, "Makes all nearby vehicles beep infinitely. May not be networked.", function(on)
    beep_cars = on
    mod_uses("vehicle", if on then 1 else -1)
end, false)

halt_traffic = false
menu.toggle(v_traffic_root, "Halt traffic", {"halttraffic"}, "Prevents all nearby vehicles from moving, at all. Not even an inch. Irreversible so be careful.", function(on)
    halt_traffic = on
    mod_uses("vehicle", if on then 1 else -1)
end)

reverse_traffic = false
menu.toggle(v_traffic_root, "Reverse traffic", {"reversetraffic"}, "Traffic, but flip it", function(on)
    reverse_traffic = on
    mod_uses("vehicle", if on then 1 else -1)
end)

vehicles_thread = util.create_thread(function (thr)
    while true do
        if vehicle_uses > 0 then
            ls_log("Vehicle pool is being updated")
            all_vehicles = entities.get_all_vehicles_as_handles()
            for k,veh in pairs(all_vehicles) do
                if vhp_bars then
                    local d_coord = ENTITY.GET_ENTITY_COORDS(veh, true)
                    d_coord['z'] = d_coord['z'] + 1.0
                    local hp = ENTITY.GET_ENTITY_HEALTH(veh)
                    local perc = hp/ENTITY.GET_ENTITY_MAX_HEALTH(veh)*100
                    if perc ~= 0 then
                        local r = 0
                        local g = 0
                        local b = 0
                        if perc == 100 then
                            r = 0
                            g = 255
                            b = 0
                        elseif perc < 100 and perc > 50 then
                            r = 255
                            g = 255
                            b = 0
                        else
                            r = 255
                            g = 0
                            b = 0
                        end
                        GRAPHICS.DRAW_MARKER(43, d_coord['x'], d_coord['y'], d_coord['z'], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.50, 0, perc/150, r, g, b, 100, false, true, 2, false, 0, 0, false)
                    end
                end
                local driver = VEHICLE.GET_PED_IN_VEHICLE_SEAT(veh, -1)
                -- FOR THINGS THAT SHOULD NOT WORK ON CARS WITH PLAYERS DRIVING THEM
                if player_cur_car ~= veh and not (PED.IS_PED_A_PLAYER(driver) or driver == 0) then
                    if not PED.IS_PED_A_PLAYER(driver) or driver == 0 then
                        if reap then
                            request_control_of_entity(veh)
                        end
                    end
                    if colorize_cars then
                        ls_log("COLORIZING")
                        VEHICLE.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(veh, rgb[1], rgb[2], rgb[3])
                        VEHICLE.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(veh, rgb[1], rgb[2], rgb[3])
                        for i=0, 3 do
                            VEHICLE._SET_VEHICLE_NEON_LIGHT_ENABLED(veh, i, true)
                        end
                        VEHICLE._SET_VEHICLE_NEON_LIGHTS_COLOUR(veh, rgb[1], rgb[2], rgb[3])
                        VEHICLE.SET_VEHICLE_LIGHTS(veh, 2)
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
menu.toggle(pickups_root, "Teleport all pickups", {"tppickups"}, "Teleports all pickups, right to you.", function(on)
    tp_all_pickups = on
    mod_uses("pickup", if on then 1 else -1)
end)

-- WORLD
menu.action(world_root, "Super cleanse", {"supercleanse"}, "Uses stand API to delete EVERY entity it finds (including player vehicles!).", function(on_click)
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
    util.toast("Super cleanse is complete! " .. ct .. " entities removed.")
end)

island_block = 0
menu.action(world_root, "Sky island", {"skyisland"}, "Your own private residence in the sky. Sorta.", function(on_click)
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
--953286133


-- TWEAKS
fakemessages_root = menu.list(tweaks_root, "Fake messages", {"lancescriptfakemessages"}, "Fake alert screens")

menu.action(tweaks_root, "Force cutscene", {"forcecutscene"}, "Input a cutscene to force. Google \"GTA V cutscene names list\". Very fun shit.", function(on_click)
    util.toast("Please type the cutscene name")
    menu.show_command_box("forcecutscene ")
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
                util.toast("Cutscene failed to load in 10 seconds.")
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

menu.toggle(tweaks_root, "Music-only radio", {"musiconly"}, "Forces radio stations to only play music. No bullshit.", function(on)
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

menu.toggle(tweaks_root, "Lock minimap angle", {"lockminimapangle"}, "In case you prefer this or something", function(on)
    if on then
        HUD.LOCK_MINIMAP_ANGLE(0)
    else
        HUD.UNLOCK_MINIMAP_ANGLE()
    end
end)

hud_rgb_index = 1
hud_rgb_colors = {6, 18, 9}
menu.toggle_loop(tweaks_root, "Party mode", {"partymode"}, "play some caramelldansen", function(on)
    HUD.FLASH_MINIMAP_DISPLAY_WITH_COLOR(hud_rgb_colors[hud_rgb_index])
    hud_rgb_index = hud_rgb_index + 1
    if hud_rgb_index == 4 then
        hud_rgb_index = 1
    end
    util.yield(200)
end)

--FLASH_MINIMAP_DISPLAY_WITH_COLOR(int hudColorIndex)


--LOCK_MINIMAP_ANGLE(int angle)


function show_custom_alert_until_enter(l1)
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

menu.action(fakemessages_root, "Fake ban message 1", {"fakeban"}, "Shows a completely fake ban message. Maybe use this to get free accounts from cheat devs or cause a scare on r/Gta5modding.", function(on_click)
    show_custom_alert_until_enter("You have been banned from Grand Theft Auto Online.~n~Return to Grand Theft Auto V.")
end)

menu.action(fakemessages_root, "Fake ban message 2", {"fakeban"}, "Shows a completely fake ban message. Maybe use this to get free accounts from cheat devs or cause a scare on r/Gta5modding.", function(on_click)
    show_custom_alert_until_enter("You have been banned from Grand Theft Auto Online permanently.~n~Return to Grand Theft Auto V.")
end)

menu.action(fakemessages_root, "Services unavailable", {"fakeservicedown"}, "rOcKstaR GaMe ServICeS ArE UnAvAiLAbLe RiGht NoW", function(on_click)
    show_custom_alert_until_enter("The Rockstar game services are unavailable right now.~n~Please return to Grand Theft Auto V.")
end)

menu.action(fakemessages_root, "Suspended until xyz", {"suspendeduntil"}, "Suspended until xyz. It will ask you to input the date to show, don\'t worry.", function(on_click)
    util.toast("Input the date your \"suspension\" should end.")
    menu.show_command_box("suspendeduntil ")
end, function(on_command)
    -- fuck it lol
    show_custom_alert_until_enter("You have been suspended from Grand Theft Auto Online until " .. on_command .. ".~n~In addition, your Grand Theft Auto Online character(s) will be reset.~n~Return to Grand Theft Auto V.")
end)

menu.action(fakemessages_root, "Stand on TOP!", {"stand on top"}, "yep", function(on_click)
    show_custom_alert_until_enter("Stand on TOP!")
end)

menu.action(fakemessages_root, "Custom alert", {"customalert"}, "Shows a custom alert of your liking. Credit to QuickNUT and Sainan for help with this.", function(on_click)
    util.toast("Please type what you want the alert to say. Type ~n~ for new line, ie foo~n~bar will show up as 2 lines.")
    menu.show_command_box("customalert ")
end, function(on_command)
    show_custom_alert_until_enter(on_command)
end)


-- PLAYERS AND TROLLING

function get_best_mug_target()
    local most = 0
    local mostp = 0
    for k,p in pairs(players.list(false, true, true)) do
        cur_wallet = players.get_wallet(p)
        if cur_wallet > most then
            most = cur_wallet
            mostp = p
        end
    end
    if cur_wallet == nil then
        util.toast("You are alone. Cannot find best mug target.")
        return
    end
    if most ~= 0 then
        return PLAYER.GET_PLAYER_NAME(mostp) .. " has the most money in their wallet ($" .. most .. "). Maybe go mug them."
    else
        util.toast("Could not find best mug target.")
        return nil
    end
end

function get_poorest_player()
    local least = 10000000000000000
    local leastp = 0
    for k,p in pairs(players.list(false, true, true)) do
        cur_assets = players.get_wallet(p) + players.get_bank(p)
        if cur_assets < least then
            least = cur_assets
            leastp = p
        end
    end
    if cur_assets == nil then
        util.toast("You are alone. Cannot find poorest player.")
        return
    end
    if least ~= 10000000000000000 then
        return PLAYER.GET_PLAYER_NAME(leastp) .. " is the poorest player in the session! (with $" .. players.get_wallet(leastp) .. " in their wallet and $" .. players.get_bank(leastp) .. " in the bank!)"
    else
        util.toast("Could not find poorest player.")
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
        util.toast("You are alone. Cannot find richest player.")
        return
    end
    if most ~= 0 then
        return PLAYER.GET_PLAYER_NAME(mostp) .. " is the richest player in the session! (with $" .. players.get_wallet(mostp) .. " in their wallet and $" .. players.get_bank(mostp) .. " in the bank!)"
    else
        util.toast("Could not find richest player.")
        return nil
    end
end


function max_out_car(veh)
    for i=0, 49 do
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

local attachall_root = menu.list(aphostile_root, "Attach", {"attach"}, "")
local flag_root = menu.list(attachall_root, "Flags", {"lsflags"}, "")

menu.action(attachall_root, "Ball", {"aaball"}, "The OG", function(on_click)
    attachall(0.0, 0.0, 0.0, 0.0, 90.0, 0.0, 148511758, 0, false, false)
end)

menu.action(attachall_root, "Cone hat", {"aacone"}, "coneheads", function(on_click)
    attachall(0.0, 0.0, 0.0, 0.0, 90.0, 0.0, 3760607069, 31086, false, false)
end)

menu.action(attachall_root, "Ferris wheel", {"aafwheel"}, "toxic", function(on_click)
    attachall(0.0, 0.0, 0.0, 0.0, 90.0, 0.0, 3291218330, 0, false, false)
end)

menu.action(attachall_root, "Windmill", {"aawindmill"}, "toxic", function(on_click)
    attachall(0.0, 0.0, 0.0, 0.0, 90.0, 0.0, 1952396163, 0, false, false)
end)

menu.action(attachall_root, "Fuel tanker", {"aatanker"}, "boom", function(on_click)
    attachall(0.0, 0.0, 0.0, 0.0, 90.0, 0.0, 3763623269, 0, false, false)
end)

menu.action(attachall_root, "NPC", {"aanpc"}, "toxic", function(on_click)
    attachall(0.0, 0.0, 0.0, 0.0, 90.0, 0.0, 0x9C9EFFD8, 0, true, false)
end)

menu.action(attachall_root, "Dick", {"aadick"}, "mature", function(on_click)
    attachall(0.15, 0.15, 0.0, -90.0, 0.0, 0.0, -422877666, 11816, false, false)
end)

menu.action(attachall_root, "Bicycle (for piggyback rides!)", {"aabike"}, "", function(on_click)
    local hash = 3061159916
    request_model_load(hash)
    for k, pid in pairs(players.list(false, true, true)) do
        attachto(0.0, -1.0, 0.0, pid, 0.0, 0.0, 0.0, hash, 0, false, true)
    end
end)

menu.action(attachall_root, "Custom object model", {"customatmodel"}, "Input a custom model to attach.", function(on_click)
    util.toast("Please input the model name")
    menu.show_command_box("customatmodel ")
end, function(on_command)
    local hash = util.joaat(on_command)
    request_model_load(hash)
    attachall(0.0, 0.0, 0.0, 0.0, 90.0, 0.0, hash, 0, false)
end)

menu.action(attachall_root, "Custom vehicle model", {"customvmodel"}, "Input a custom model to attach.", function(on_click)
    util.toast("Please input the model name")
    menu.show_command_box("customvmodel ")
end, function(on_command)
    local hash = util.joaat(on_command)
    request_model_load(hash)
    for k, pid in pairs(players.list(false, true, true)) do
        attachto(0.0, 0.0, 0.0, pid, 0.0, 0.0, 0.0, hash, 0, false, true)
    end
end)

menu.action(ap_vaddons, "Ramp", {"apvaddonramp"}, "", function(on_click)
    give_all_car_addon(util.joaat("prop_mp_ramp_01"), false, 180)
end)

menu.action(ap_vaddons, "Tube", {"apvaddontube"}, "", function(on_click)
    give_all_car_addon(util.joaat("stt_prop_stunt_tube_speedb"), true, 90.0)
end)

menu.action(ap_vaddons, "Lochness monster", {"apvaddonloch"}, "", function(on_click)
    give_all_car_addon(util.joaat("h4_prop_h4_loch_monster"), true, -90.0)
end)

menu.action(ap_vaddons, "Custom model", {"customvaddonmdl"}, "Input a custom model to attach. The model string, NOT the hash.", function(on_click)
    util.toast("Please input the model hash")
    menu.show_command_box("customvaddonmdl ")
end, function(on_command)
    local hash = util.joaat(on_command)
    give_all_car_addon(hash, true, 0.0)
end)

-- INDIVIDUAL PLAYER SEGMENTS
num_attackers = 1
godmodeatk = true
freezeloop = false
freezetar = -1
atkgun = 0

function tp_player_car_to_coords(pid, coord)
    local name = PLAYER.GET_PLAYER_NAME(pid)
    if robustmode then
        menu.trigger_commands("spectate" .. name .. " on")
        util.yield(1000)
    end
    local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
    if car ~= 0 then
        request_control_of_entity(car)
        if NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(car) then
            for i=1, 3 do
                util.toast("Success")
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

givegun = false
num_attackers = 1
function send_attacker(hash, pid, givegun)
    local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
    coords = ENTITY.GET_ENTITY_COORDS(target_ped, false)
    coords.x = coords['x']
    coords.y = coords['y']
    coords.z = coords['z']
    request_model_load(hash)
    for i=1, num_attackers do
        local attacker = entities.create_ped(28, hash, coords, math.random(0, 270))
        if godmodeatk then
            ENTITY.SET_ENTITY_INVINCIBLE(attacker, true)
        end
        TASK.TASK_COMBAT_PED(attacker, target_ped, 0, 16)
        PED.SET_PED_ACCURACY(attacker, 100.0)
        PED.SET_PED_COMBAT_ABILITY(attacker, 2)
        PED.SET_PED_AS_ENEMY(attacker, true)
        PED.SET_PED_FLEE_ATTRIBUTES(attacker, 0, false)
        PED.SET_PED_COMBAT_ATTRIBUTES(attacker, 46, true)
        if givegun then
            WEAPON.GIVE_WEAPON_TO_PED(attacker, atkgun, 0, false, true)
        end
    end
end

function send_aircraft_attacker(vhash, phash, pid)
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

function send_groundv_attacker(vhash, phash, pid, givegun)
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
        for i=-1, VEHICLE.GET_VEHICLE_MODEL_NUMBER_OF_SEATS(vhash) - 2 do
            local rider = entities.create_ped(1, phash, spawn_pos, 0.0)
            if i == -1 then
                TASK.TASK_VEHICLE_CHASE(rider, target_ped)
            end
            max_out_car(atkbike)
            PED.SET_PED_INTO_VEHICLE(rider, bike, i)
            WEAPON.GIVE_WEAPON_TO_PED(rider, atkgun, 1000, false, true)
            PED.SET_PED_COMBAT_ATTRIBUTES(rider, 5, true)
            PED.SET_PED_COMBAT_ATTRIBUTES(rider, 46, true)
            TASK.TASK_COMBAT_PED(rider, player_ped, 0, 16)
            if godmodeatk then
                ENTITY.SET_ENTITY_INVINCIBLE(bike, true)
                ENTITY.SET_ENTITY_INVINCIBLE(rider, true)
            end

            if givegun then
                WEAPON.GIVE_WEAPON_TO_PED(rider, atkgun, 0, false, true)
            end
        end
    end
end

function send_player_label_sms(label, pid)
    local event_data = {-1702264142, players.user(), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    local out = label:sub(1, 127)
    for i = 0, #out -1 do
        local slot = i // 8
        local byte = string.byte(out, i + 1)
        event_data[slot + 3] = event_data[slot + 3] | byte << ( (i - slot * 8) * 8)
    end
    util.trigger_script_event(1 << pid, event_data)
end

function set_up_player_actions(pid)
    ls_log("Setting up player actions for pid " .. pid)
    menu.divider(menu.player_root(pid), "LanceScript Reloaded")
    local ls_friendly = menu.list(menu.player_root(pid), "Lancescript: Friendly", {"lsfriendly"}, "")
    ls_log("Set up vaddons for pid " .. pid)
    local ls_vaddons = menu.list(ls_friendly, "Vehicle addons", {"lsvaddons"}, "")
    ls_log("Set up ls hostile for pid " .. pid)
    local ls_hostile = menu.list(menu.player_root(pid), "Lancescript: Hostile", {"lshostile"}, "")
    --local scriptevents = menu.list(ls_hostile, "Script events", {"lsse"}, "Send script events to the player to do various things")
    local ls_neutral = menu.list(menu.player_root(pid), "Lancescript: Neutral", {"lsneutral"}, "")
    spawnvehicle_root = menu.list(ls_friendly, "Give vehicle", {"spawnveh"}, "")
    explosions_root = menu.list(ls_hostile, "Projectiles/explosions", {"lancescriptexplosions"}, "Fire jet, water jet, launch player, etc.")
    forcedacts_root = menu.list(ls_neutral, "Forced actions", {"forcedacts"}, "")
    forcedacts_tp_root = menu.list(forcedacts_root, "Teleport", {"forcedactstp"}, "")
    npctrolls_root = menu.list(ls_hostile, "NPC trolling", {"npctrolls"}, "")
    attackers_root = menu.list(npctrolls_root, "Attackers", {"lancescriptattackers"}, "Send attackers")
    customatk_root = menu.list(attackers_root, "Custom attackers", {"lancescriptcustomatk"}, "Spawn custom attackers")
    objecttrolls_root = menu.list(ls_hostile, "Object trolling", {"objecttrolls"}, "")
    texts_root = menu.list(ls_neutral, "Texts", {"hostiletexts"}, "")
    ram_root = menu.list(ls_hostile, "Ram", {"ram"}, "")
    ls_log("Set up roots for pid " .. pid)
    ls_log("Adding menu actions and toggles for pid " .. pid)

    menu.action(forcedacts_tp_root, "Teleport vehicle to me", {"tpvtome"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on_click)
        tp_player_car_to_coords(pid, ENTITY.GET_ENTITY_COORDS(players.user_ped(), true))
    end)
    ls_log("tpvtome added")

    menu.action(forcedacts_tp_root, "Teleport vehicle to waypoint", {"tpvtoway"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on_click)
        local c = get_waypoint_coords()
        if c ~= nil then
            tp_player_car_to_coords(pid, c)
        end
    end)
    ls_log("tpvtoway added")

    menu.action(forcedacts_tp_root, "Teleport vehicle to Maze Bank helipad", {"tpvtomaze"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on_click)
        local c = {}
        c.x = -75.261375
        c.y = -818.674
        c.z = 326.17517
        tp_player_car_to_coords(pid, c)
    end)
    ls_log("forcedact mazebank added")

    menu.action(forcedacts_tp_root, "Teleport vehicle deep underwater", {"tpvunderwater"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on_click)
        local c = {}
        c.x = 4497.2207
        c.y = 8028.3086
        c.z = -32.635174
        tp_player_car_to_coords(pid, c)
    end)

    menu.action(forcedacts_tp_root, "Teleport vehicle high up", {"tpvhighup"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on_click)
        local c = {}
        c.x = 0.0
        c.y = 0.0
        c.z = 2000
        tp_player_car_to_coords(pid, c)
    end)

    ls_log("forcedact teleport added")

    menu.action(forcedacts_tp_root, "Teleport vehicle into LSC", {"tpvlsc"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on_click)
        local c = {}
        c.x = -353.84512
        c.y = -135.59108
        c.z = 39.009624
        tp_player_car_to_coords(pid, c)
    end)

    menu.action(forcedacts_tp_root, "Teleport vehicle into bennys", {"tpvbennys"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on_click)
        local c = {}
        c.x = -206.46237
        c.y = -1308.9502
        c.z = 31.29596
        tp_player_car_to_coords(pid, c)
    end)

    menu.action(forcedacts_tp_root, "Teleport vehicle into SCP-173 cell", {"tpvscp"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on_click)
        local c = {}
        c.x = 1642.8401
        c.y = 2570.7695
        c.z = 45.564854
        tp_player_car_to_coords(pid, c)
    end)

    menu.action(forcedacts_tp_root, "Teleport vehicle into large cell", {"tpvcell"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on_click)
        local c = {}
        c.x = 1737.1896
        c.y = 2634.897
        c.z = 45.56497
        tp_player_car_to_coords(pid, c)
    end)

    menu.action(forcedacts_root, "Destroy vehicle engine", {"destroyvengine"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on_click)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            VEHICLE.SET_VEHICLE_ENGINE_HEALTH(car, -4000.0)
        end
    end)
    ls_log("forcedact destroyeng added")

    menu.action(forcedacts_root, "Repair vehicle :)", {"repairveh"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on_click)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            VEHICLE.SET_VEHICLE_ENGINE_HEALTH(car, 1000.0)
            VEHICLE.SET_VEHICLE_FIXED(car)
            VEHICLE.SET_VEHICLE_BODY_HEALTH(car, 10000.0)
        end
    end)
    ls_log("forcedact repairv added")

    menu.action(forcedacts_root, "Yeet vehicle", {"yeetv"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on_click)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            ENTITY.APPLY_FORCE_TO_ENTITY(car, 2, 0, 0, 10000000, 0, 0, 0, 0, true, false, true, false, true)
        end
    end)
    ls_log("forcedact yeet added")

    menu.action(forcedacts_root, "Detach from trailer", {"detachv"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on_click)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            VEHICLE.DETACH_VEHICLE_FROM_TRAILER(car)
        end
    end)
    ls_log("forcedact detachv added")

    menu.action(forcedacts_root, "Set license plate to LANCE", {"lancelicense"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on_click)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(car, "LANCE")
        end
    end)
    ls_log("forcedact licenselance added")

    menu.action(forcedacts_root, "Set license plate to STAND", {"standlicense"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on_click)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(car, "STAND")
        end
    end)
    ls_log("forcedact stand added")

    menu.action(forcedacts_root, "Custom plate text", {"customplatetext"}, "", function(on_click)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            util.toast("Please input the plate text")
            menu.show_command_box("customplatetext" .. PLAYER.GET_PLAYER_NAME(pid) .. " ")
        end
    end, function(on_command)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if #on_command <= 8 then
            request_control_of_entity(car)
            VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(car, on_command)
        else
            util.toast("Too many characters. Please re-input plate text.")
            menu.show_command_box("customplatetext" .. PLAYER.GET_PLAYER_NAME(pid) .. " ")
        end
    end)
    ls_log("forcedact customplate added")

    
    menu.action(forcedacts_root, "Open all car doors", {"opendoors"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on_click)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            local d = VEHICLE._GET_NUMBER_OF_VEHICLE_DOORS(car)
            for i=1, d do
                VEHICLE.SET_VEHICLE_DOOR_OPEN(car, i, false, true)
            end
        end
    end)
    ls_log("forcedact opendoors added")
        
    menu.action(forcedacts_root, "Close all car doors", {"opendoors"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on_click)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            local d = VEHICLE._GET_NUMBER_OF_VEHICLE_DOORS(car)
            for i=1, d do
                VEHICLE.SET_VEHICLE_DOOR_SHUT(car, i, false)
            end
        end
    end)
    ls_log("forcedact closedoors added")

    menu.action(forcedacts_root, "Godmode vehicle", {"godmodev"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on_click)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            ENTITY.SET_ENTITY_INVINCIBLE(car, true)
            VEHICLE.SET_VEHICLE_CAN_BE_VISIBLY_DAMAGED(car, false)
        end
    end)
    ls_log("forcedact godmodev added")

    menu.click_slider(forcedacts_root, "Vehicle top speed", {"vtopspeed"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", 0, 3000, 200, 100, function(s)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            VEHICLE.MODIFY_VEHICLE_TOP_SPEED(car, s)
        end
    end)
    ls_log("forcedact topspeed added")

    menu.toggle(forcedacts_root, "Invisible vehicle", {"invisv"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on)
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
    ls_log("forcedact invisv added")

    menu.toggle(forcedacts_root, "Attach vehicle to my vehicle", {"attachvtomyv"}, "This MAY OR MAY NOT WORK. It is NOT a bug if this does not work.", function(on)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if car ~= 0 then
            request_control_of_entity(car)
            if on then
                ENTITY.ATTACH_ENTITY_TO_ENTITY(car, player_cur_car, 0, 0.0, -5.00, 0.00, 1.0, 1.0,1, true, true, true, false, 0, true)
            else
                ENTITY.DETACH_ENTITY(car, false, false)
            end
        end
    end, false)
    ls_log("forcedact attachv added")

    menu.action(ls_friendly, "Remove stickybombs from car", {"removebombs"}, "", function(on_click)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        NETWORK.REMOVE_ALL_STICKY_BOMBS_FROM_ENTITY(car)
    end)
    ls_log("forcedact removesticky added")

    menu.action(ls_vaddons, "Ramp", {"addramp"}, "", function(on_click)
        give_car_addon(pid, util.joaat("prop_mp_ramp_01"), false, 180.0)
    end)

    menu.action(ls_vaddons, "Tube", {"addtube"}, "", function(on_click)
        give_car_addon(pid, util.joaat("stt_prop_stunt_tube_speedb"), true, 90.0)
    end)

    menu.action(ls_vaddons, "Lochness monster", {"addloch"}, "", function(on_click)
        give_car_addon(pid, util.joaat("h4_prop_h4_loch_monster"), true, -90.0)
    end)

    menu.action(ls_vaddons, "Custom model", {"customplyrvadmdl"}, "Input a custom model to attach. The model string, NOT the hash.", function(on_click)
        util.toast("Please input the model hash")
        menu.show_command_box("customplyrvadmdl" .. PLAYER.GET_PLAYER_NAME(pid) .. " ")
    end, function(on_command)
        local hash = util.joaat(on_command)
        give_car_addon(pid, hash, true, 0.0)
    end)

    menu.action(ls_hostile, "Crush player", {"crush"}, "Spawns a heavy truck several meters above them and forces its Z velocity to -100 to absolutely decimate them when it lands.", function(on_click)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        coords = ENTITY.GET_ENTITY_COORDS(target_ped, false)
        coords.x = coords['x']
        coords.y = coords['y']
        coords.z = coords['z'] + 20.0
        request_model_load(1917016601)
        local truck = entities.create_vehicle(1917016601, coords, 0.0)
        --local vel = ENTITY.GET_ENTITY_VELOCITY(vel)
        --ENTITY.SET_ENTITY_VELOCITY(truck, vel['x'], vel['y'], -100.0)
    end)

    menu.action(spawnvehicle_root, "Space docker", {"givespacedocker"}, "beep boop", function(on_click)
        give_vehicle(pid, util.joaat("dune2"))
    end)

    menu.action(spawnvehicle_root, "Clown van", {"giveclownvan"}, "what you are", function(on_click)
        give_vehicle(pid, util.joaat("speedo2"))
    end)

    menu.action(spawnvehicle_root, "Krieger", {"apkrieger"}, "its fast lol", function(on_click)
        give_vehicle(pid, util.joaat("krieger"))
    end)
    
    menu.action(spawnvehicle_root, "Kuruma", {"apkuruma"}, "the 12 year old\'s dream", function(on_click)
        give_vehicle(pid, util.joaat("kuruma"))
    end)
    
    menu.action(spawnvehicle_root, "Insurgent", {"apinsurgent"}, "the 10 year old\'s dream", function(on_click)
        give_vehicle(pid, util.joaat("insurgent"))
    end)
    
    menu.action(spawnvehicle_root, "Neon", {"apneon"}, "electric car underrated and go brrt", function(on_click)
        give_vehicle(pid, util.joaat("neon"))
    end)
    
    menu.action(spawnvehicle_root, "Akula", {"apakula"}, "a good heli", function(on_click)
        give_vehicle(pid, util.joaat("akula"))
    end)
    
    menu.action(spawnvehicle_root, "Alpha Z-1", {"apakula"}, "super fucking fast plane lol", function(on_click)
        give_vehicle(pid, util.joaat("alphaz1"))
    end)
    
    menu.action(spawnvehicle_root, "Rogue", {"aprogue"}, "good attak plane", function(on_click)
        give_vehicle(pid, util.joaat("rogue"))
    end)

    menu.action(spawnvehicle_root, "Input custom vehicle name", {"givecarinput"}, "Input a custom vehicle name to spawn (the NAME, NOT HASH)", function(on_click)
        util.toast("Please type the vehicle name")
        menu.show_command_box("givecarinput" .. PLAYER.GET_PLAYER_NAME(pid) .. " ")
    end, function(on_command)
        give_vehicle(pid, util.joaat(on_command))
    end)

    menu.action(ram_root, "Howard", {"ramhoward"}, "brrt", function(on_click)
        ram_ped_with(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), -1007528109, 10.0, true)
    end)

    menu.toggle(ram_root, "Set on ground", {"ramonground"}, "Leave off if the user is flying aircraft", function(on)
        ram_onground = on
    end, true)

    menu.action(ram_root, "Rally truck", {"ramtruck"}, "vroom", function(on_click)
        ram_ped_with(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), -2103821244, 10.0, false)
    end)

    menu.action(ram_root, "Cargo plane", {"ramcargo"}, "some menus might have this blocked lol", function(on_click)
        ram_ped_with(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), 368211810, 15.0, false)
    end)

    menu.action(ram_root, "Phantom wedge", {"ramwedge"}, "they fly", function(on_click)
        ram_ped_with(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), -1649536104, 15.0, false)
    end)

    menu.action(explosions_root, "Fire jet", {"firejet"}, "one of the classic trolls", function(on_click)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local coords = ENTITY.GET_ENTITY_COORDS(target_ped, false)
        FIRE.ADD_EXPLOSION(coords['x'], coords['y'], coords['z'], 12, 100.0, true, false, 0.0)
    end)

    menu.toggle(ls_hostile, "Vehicle limp", {"vehiclelimp"}, "Makes the player\'s vehicle \"limp\" by creating a fight for entity ownership of it between you and the player. May raise red flags on some menus.", function(on)
        local ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local car = PED.GET_VEHICLE_PED_IS_IN(ped)
        request_control_of_entity(car)
    end)

    menu.toggle_loop(explosions_root, "Fire jet loop", {"firejetloop"}, "For if someone REALLY pisses you off, x2", function(on)
        local coords = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid))
        FIRE.ADD_EXPLOSION(coords['x'], coords['y'], coords['z'], 12, 100.0, true, false, 0.0)
    end)


    menu.action(explosions_root, "Water jet", {"waterjet"}, "one of the classic trolls", function(on_click)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local coords = ENTITY.GET_ENTITY_COORDS(target_ped, false)
        FIRE.ADD_EXPLOSION(coords['x'], coords['y'], coords['z'], 13, 100.0, true, false, 0.0)
    end)

    menu.toggle_loop(explosions_root, "Water jet loop", {"waterjetloop"}, "One of the classic trolls, x2", function(on)
        local coords = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid))
        FIRE.ADD_EXPLOSION(coords['x'], coords['y'], coords['z'], 13, 100.0, true, false, 0.0)
    end)

    menu.toggle(ls_neutral, "Attach to player", {"attachto"}, "Useful, because if you\'re near the player your trolling works better", function(on)
        if on then
            ENTITY.ATTACH_ENTITY_TO_ENTITY(players.user_ped(), PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), 0, 0.0, -0.20, 2.00, 1.0, 1.0,1, true, true, true, false, 0, true)
        else
            ENTITY.DETACH_ENTITY(players.user_ped(), false, false)
        end
    end, false)


    menu.toggle(ls_neutral, "Attach to player car", {"attachtocar"}, "Only works if they have a car/last car", function(on)
        local lastveh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if on and lastveh ~= 0 then
            ENTITY.ATTACH_ENTITY_TO_ENTITY(players.user_ped(), lastveh, 0, 0.0, -0.20, 2.00, 1.0, 1.0,1, true, true, true, false, 0, true)
        else
            ENTITY.DETACH_ENTITY(players.user_ped(), false, false)
        end
    end, false)

    menu.toggle(ls_neutral, "Attach current car to player car", {"attachcurrenttocar"}, "Only works if they have a car/last car", function(on)
        local lastveh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        if on and player_cur_car and lastveh ~= 0 then
            ENTITY.ATTACH_ENTITY_TO_ENTITY(player_cur_car, lastveh, 0, 0.0, -5.00, 0.00, 1.0, 1.0,1, true, true, true, false, 0, true)
        else
            ENTITY.DETACH_ENTITY(player_cur_car, false, false)
        end
    end, false)

    menu.action(ls_hostile, "Chop up", {"chopup"}, "Makes chop suey of the player with helicopter blades. Works best if your player is nearby.", function(on_click)
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

    menu.toggle(ls_hostile, "Blackhole target", {"bhtarget"}, "A really toxic thing to do but you should do it anyways because it\'s fun. Obviously requires blackhole to be on.", function(on)
        if on then
            if not blackhole then
                blackhole = true
                menu.trigger_commands("blackhole on")
            end
            bh_target = pid
        else
            bh_target = -1
            if blackhole then
                blackhole = false
                menu.trigger_commands("blackhole off")
            end
        end
    end, false)

    menu.action(customatk_root, "Custom ped model", {"custompedmodel"}, "Input a custom model for the attacker. The model string, NOT the hash.", function(on_click)
        util.toast("Please input the model hash")
        menu.show_command_box("custompedmodel" .. PLAYER.GET_PLAYER_NAME(pid) .. " ")
    end, function(on_command)
        send_attacker(util.joaat(on_command), pid, true)
    end)

    menu.action(attackers_root, "Dog attack", {"dogatk"}, "arf uwu", function(on_click)
        send_attacker(-1788665315, pid, false)
    end)


    menu.action(attackers_root, "Mountain lion attack", {"cougaratk"}, "rawr", function(on_click)
        send_attacker(307287994, pid, false)
    end)

    menu.action(attackers_root, "Brad attack", {"bradatk"}, "scary", function(on_click)
        send_attacker(util.joaat("CS_BradCadaver"), pid, false)
    end)

    --WEAPON.GIVE_WEAPON_TO_PED(ped, 453432689, 0, false, true)

    --ATTACH_VEHICLE_TO_TOW_TRUCK(Vehicle towTruck, Vehicle vehicle, BOOL rear, float hookOffsetX, float hookOffsetY, float hookOffsetZ)
    menu.action(npctrolls_root, "Tow last car", {"towtruck"}, "They didn\'t pay their lease.", function(on_click)
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
            if towfrombehind then
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

    
    menu.toggle(npctrolls_root, "Tow from behind", {"towbehind"}, "Toggle on if the front of the car is blocked", function(on)
        towfrombehind = on
    end)

    menu.action(npctrolls_root, "Cat explosion", {"meow"}, "UWU", function(on_click)
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

    menu.action(attackers_root, "Send jets", {"sendjets"}, "We don\'t charge $140 for this extremely basic feature. However the jets will only target the player until the player dies, otherwise we would need another thread, and I don\'t want to make one.", function(on_click)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        coords = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(target_ped, 1.0, 0.0, 500.0)
        coords.x = coords['x']
        coords.y = coords['y']
        coords.z = coords['z']
        local hash = util.joaat("lazer")
        request_model_load(hash)
        request_model_load(-163714847)
        for i=1, num_attackers do
            coords.x = coords.x + i*2
            coords.y = coords.y + i*2
            local jet = entities.create_vehicle(hash, coords, 0.0)
            VEHICLE.CONTROL_LANDING_GEAR(jet, 3)
            VEHICLE.SET_HELI_BLADES_FULL_SPEED(jet)
            VEHICLE.SET_VEHICLE_FORWARD_SPEED(jet, VEHICLE.GET_VEHICLE_ESTIMATED_MAX_SPEED(jet))
            if godmodeatk then
                ENTITY.SET_ENTITY_INVINCIBLE(jet, true)
            end
            local pilot = entities.create_ped(28, -163714847, coords, 30.0)
            PED.SET_PED_COMBAT_ATTRIBUTES(pilot, 5, true)
            PED.SET_PED_COMBAT_ATTRIBUTES(pilot, 46, true)
            PED.SET_PED_INTO_VEHICLE(pilot, jet, -1)
            TASK.TASK_PLANE_MISSION(pilot, jet, 0, target_ped, 0, 0, 0, 6, 0.0, 0, 0.0, 50.0, 40.0)
            TASK.TASK_COMBAT_PED(pilot, target_ped, 0, 16)
            PED.SET_PED_ACCURACY(pilot, 100.0)
            PED.SET_PED_COMBAT_ABILITY(pilot, 2)
        end
    end)
    
    menu.action(attackers_root, "Send A10s", {"senda10s"}, "literally just a model swap of the send jets why would u want this", function(on_click)
        send_aircraft_attacker(1692272545, -163714847, pid)
    end)

    menu.action(attackers_root, "Send cargo planes", {"sendcargoplanes"}, "it doesnt have guns but you know, whatever. also the back is forced open so u can land in it lol", function(on_click)
        send_aircraft_attacker(util.joaat("cargoplane"), -163714847, pid)
    end)

    menu.action(customatk_root, "Custom aircraft attacker", {"customaircraftatk"}, "Input a custom model for the attacker\'s aircraft.", function(on_click)
        util.toast("Please input the model hash")
        menu.show_command_box("customaircraftatk" .. PLAYER.GET_PLAYER_NAME(pid) .. " ")
    end, function(on_command)
        send_aircraft_attacker(util.joaat(on_command), -163714847, pid)
    end)

    menu.action(customatk_root, "Custom ground vehicle attacker", {"customgvatk"}, "Input a custom model for the attacker\'s ground vehicle.", function(on_click)
        util.toast("Please input the model hash")
        menu.show_command_box("customgvatk" .. PLAYER.GET_PLAYER_NAME(pid) .. " ")
    end, function(on_command)
        send_groundv_attacker(util.joaat(on_command), 850468060, pid, true)
    end)

    menu.slider(attackers_root, "Number of attackers", {"numattackers"}, "Number of attackers to send", 1, 30, 1, 1, function(s)
        num_attackers = s
    end)

    menu.action(objecttrolls_root, "Ramp in front of player", {"ramp"}, "Spawns a ramp right in front of the player. Most friendlyly used when they are in a car.", function(on_click)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local hash = 2282807134
        request_model_load(hash)
        local ramp = spawn_object_in_front_of_ped(target_ped, hash, 90, 50.0, -1, true)
        local c = ENTITY.GET_ENTITY_COORDS(ramp, true)
        ENTITY.SET_ENTITY_COORDS_NO_OFFSET(ramp, c['x'], c['y'], c['z']-0.2, false, false, false)
    end)

    menu.action(objecttrolls_root, "Barrier in front of player", {"barrier"}, "Spawns a *frozen* barrier right in front of the player. Good for causing accidents.", function(on_click)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local hash = 3729169359
        local obj = spawn_object_in_front_of_ped(target_ped, hash, 0, 5.0, -0.5, false)
        ENTITY.FREEZE_ENTITY_POSITION(obj, true)
    end)

    menu.action(objecttrolls_root, "Windmill player", {"windmill"}, "gotem.", function(on_click)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local hash = 1952396163
        local obj = spawn_object_in_front_of_ped(target_ped, hash, 0, 5.0, -30, false)
        ENTITY.FREEZE_ENTITY_POSITION(obj, true)
    end)

    menu.action(objecttrolls_root, "Radar player", {"radar"}, "also gotem.", function(on_click)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local hash = 2306058344
        local obj = spawn_object_in_front_of_ped(target_ped, hash, 0, 0.0, -5.0, false)
        ENTITY.FREEZE_ENTITY_POSITION(obj, true)
    end)

    menu.action(ls_hostile, "Snipe", {"snipe"}, "Snipes the player with you as the attacker [Will not work if you do not have LOS with the target]", function(on_click)
        local owner = players.user_ped()
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local target = ENTITY.GET_ENTITY_COORDS(target_ped)
        MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(target['x'], target['y'], target['z'], target['x'], target['y'], target['z']+0.1, 300.0, true, 100416529, owner, true, false, 100.0)
    end)

    menu.action(explosions_root, "Launch player", {"launchplayer"}, "launches them with the uhhh ray gun or whatever. also creates a VERY considerable amount of ear pain.", function(on_click)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local coords = ENTITY.GET_ENTITY_COORDS(target_ped)
        FIRE.ADD_EXPLOSION(coords['x'], coords['y'], coords['z'], 70, 1.0, true, false, 0.0)
    end)
    --741814745
    
    menu.toggle_loop(explosions_root, "Launch player loop", {"launchplayerloop"}, "For if someone REALLY pisses you off", function(on)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local coords = ENTITY.GET_ENTITY_COORDS(target_ped)
        FIRE.ADD_EXPLOSION(coords['x'], coords['y'], coords['z'], 70, 1.0, true, false, 0.0)
    end)

    menu.slider(explosions_root, "Custom explosion", {"customexploslider"}, "The custom explosion enum to use.", 0, 82, 0, 1, function(s)
        customexplosion = s
      end)

    menu.toggle_loop(explosions_root, "Custom explosion loop", {"customexplosions"}, "", function(on)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local coords = ENTITY.GET_ENTITY_COORDS(target_ped)
        FIRE.ADD_EXPLOSION(coords['x'], coords['y'], coords['z'], customexplosion, 1.0, true, false, 0.0)
    end)

    menu.toggle_loop(explosions_root, "Random explosion loop", {"randomexplosions"}, "", function(on)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local coords = ENTITY.GET_ENTITY_COORDS(target_ped)
        FIRE.ADD_EXPLOSION(coords['x'], coords['y'], coords['z'], math.random(0, 82), 1.0, true, false, 0.0)
    end)


    menu.action(ls_hostile, "Drop anon stickybomb", {"anonsticky"}, "Stubborn, but works when it works.", function(on_click)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local target = ENTITY.GET_ENTITY_COORDS(target_ped)
        local random_ped = get_random_ped()
        MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(target['x'], target['y'], target['z'], target['x'], target['y'], target['z']-1.0, 300.0, true, 741814745, random_ped, true, false, 100.0)
    end)

    --SET_VEHICLE_WHEEL_HEALTH(Vehicle vehicle, int wheelIndex, float health)
    menu.action(ls_hostile, "Cage", {"lscage"}, "Basic cage option. Cause you cant handle yourself. We are a little more ethical here at Lance Studios though, so the cage has some wiggle room (our special cage model also means that like, no menu blocks the model).", function(on_click)
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

    menu.action(ls_hostile, "Delete vehicle", {"deleteveh"}, "delete the vehicle they\'re in lol", function(on_click)
        local car = PED.GET_VEHICLE_PED_IS_IN(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid), true)
        entities.delete(car)
    end)

    menu.action(ls_hostile, "Cargo plane trap", {"cargoplanetrap"}, "Traps the player in a cargo plane.", function(on_click)
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

    menu.action(ls_hostile, "Raise player", {"raise"}, "Raises the player up with an invisible platform. At its best, this will fall kill the player if they dont deploy a chute. At its worst, it will just glitch the player around.", function(on_click)
        local ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local hash = util.joaat("stt_prop_stunt_bblock_mdm3")
        request_model_load(hash)
        local c = ENTITY.GET_ENTITY_COORDS(ped, false)
        local lifter = OBJECT.CREATE_OBJECT_NO_OFFSET(hash, c['x'], c['y'], c['z'], true, false, false)
        ENTITY.SET_ENTITY_ALPHA(lifter, 0)
        ENTITY.SET_ENTITY_VISIBLE(lifter, false, 0)
        local start_z_off = 0
        for i=1, 500 do
            local c = ENTITY.GET_ENTITY_COORDS(ped, false)
            c.z = c.z - 1
            start_z_off = start_z_off + 0.002
            ENTITY.SET_ENTITY_COORDS(lifter, c.x, c.y, c.z+start_z_off, false, false, false, false)
            util.yield(5)
        end
        entities.delete(lifter)
    end)    
    
    menu.action(texts_root, "Send nudes", {"sendnudes"}, ";)", function(on_click)
        for i=1, #sexts do
            send_player_label_sms(sexts[i], pid)
        end
    end)

    menu.toggle_loop(texts_root, "Spam nudes", {"spamsexts"}, ";)", function(on)
        for i=1, #sexts do
            send_player_label_sms(sexts[i], pid)
            util.yield()
        end
    end)

    menu.action(texts_root, "Spam random texts", {"spamlabels"}, "very toxic", function(on)
        for i=1, 1000 do
            send_player_label_sms(all_labels[math.random(1, #all_labels)], pid)
            util.yield()
        end
    end)

    menu.action(npctrolls_root, "NPC jack last car v3.0", {"npcjack"}, "Sends an NPC to steal their car.", function(on_click)
        npc_jack(pid, false)
    end)

    menu.action(attackers_root, "Bri'ish mode", {"british"}, "God save the queen.", function(on_click)
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
    end)

    menu.toggle(npctrolls_root, "Nearby peds combat player", {"combat"}, "Tells nearby peds to combat the player.", function(on)
        combat_tar = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        if on then
            aped_combat = true
            mod_uses("ped", 1)
        else
            aped_combat = false
            mod_uses("ped", -1)
        end
    end)

    menu.action(npctrolls_root, "Fill car with peds", {"fillcar"}, "Fills the player\'s car with nearby peds", function(on_click)
        local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        if PED.IS_PED_IN_ANY_VEHICLE(target_ped, true) then
                local veh = PED.GET_VEHICLE_PED_IS_IN(target_ped, false)
                local success = true
                while VEHICLE.ARE_ANY_VEHICLE_SEATS_FREE(veh) do
                    util.yield()
                    --  sometimes peds fail to get seated, so we will have something to break after 10 attempts if things go south
                    local iteration = 0
                    if iteration >= 20 then
                        util.toast("Failed to fully fill vehicle after 20 attempts. Please try again.")
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
                    util.toast("Every available seat should now be full of peds. If it isn\'t, try spamming this or try again in a bit.")
                end
        else
            util.toast("Player is not in a car :(")
        end
    end)
    
    menu.toggle(npctrolls_root, "Nearby traffic chases player", {"pedchase"}, "", function(on)
        ped_chase = on
        mod_uses("ped", if on then 1 else -1)
    end, false)

    menu.action(attackers_root, "Clown attack", {"clownattack"}, "Sends clowns to attack the player", function(on_click)
        local player_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        local clown_hash = 71929310
        request_model_load(clown_hash)
        local van_hash = util.joaat("speedo2")
        request_model_load(van_hash)
        local coords = ENTITY.GET_ENTITY_COORDS(player_ped, true)
        local spawn_pos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(player_ped, 0.0, -10.0, 0.0)
        spawn_pos.x = spawn_pos['x']
        spawn_pos.y = spawn_pos['y']
        spawn_pos.z = spawn_pos['z']
        local van = entities.create_vehicle(van_hash, spawn_pos, ENTITY.GET_ENTITY_HEADING(player_ped))
        if godmodeatk then
            ENTITY.SET_ENTITY_INVINCIBLE(van, true)
        end
        for i=-1, VEHICLE.GET_VEHICLE_MAX_NUMBER_OF_PASSENGERS(van) - 1 do
            local clown = entities.create_ped(1, clown_hash, spawn_pos, 0.0)
            PED.SET_PED_INTO_VEHICLE(clown, van, i)
            if i % 2 == 0 then
                WEAPON.GIVE_WEAPON_TO_PED(clown, -1810795771, 1000, false, true)
            else
                WEAPON.GIVE_WEAPON_TO_PED(clown, 584646201, 1000, false, true)
            end
            PED.SET_PED_COMBAT_ATTRIBUTES(clown, 5, true)
            PED.SET_PED_COMBAT_ATTRIBUTES(clown, 46, true)
            if i == -1 then
                TASK.TASK_VEHICLE_CHASE(clown, player_ped)
            else
                TASK.TASK_COMBAT_PED(clown, player_ped, 0, 16)
            end
            if godmodeatk then
                ENTITY.SET_ENTITY_INVINCIBLE(clown, true)
            end
        end
    end)

    menu.action(attackers_root, "Motorcycle gang attack", {"mcgangattack"}, "Sends a motorcycle gang to attack the player", function(on_click)
        send_groundv_attacker(-159126838, 850468060, pid, true)
    end)

    menu.action(attackers_root, "Helicopter attack", {"heliattack"}, "Send an attack chopper to attack the player", function(on_click)
        send_aircraft_attacker(1543134283, util.joaat("mp_m_bogdangoon"), pid)
    end)

    menu.slider(attackers_root, "Gun to give to attackers", {"giveatkgun"}, "0 = none\n1 = pistol\n2 = combat pdw\n3 = shotgun\n4 = Knife\nDoes not affect some attacker options.", 0, 10, 0, 1, function(s)
        if s == 0 then
            atkgun = 0
        else
            atkgun = good_guns[s]
        end
      end)

    menu.action(customatk_root, "Input weapon hash to give", {"customwephash"}, "Input a custom weapon hash for the attacker. You must enter the hash for this one, not the string.", function(on_click)
        util.toast("Please input the weapon hash")
        menu.show_command_box("customwephash" .. PLAYER.GET_PLAYER_NAME(pid) .. " ")
    end, function(on_command)
        atkgun = on_command
        util.toast("Weapon set to " .. on_command)
    end)

    menu.toggle(attackers_root, "Godmode attackers", {"godmodeatk"}, "Godmodes attackers. Some things are intentionally left out of this, because I think it\'s funner that way. Cry.", function(on)
        godmodeatk = on
    end, false)
end


broke_blips = {}
broke_radar = false
menu.toggle(aphostile_root, "Broke radar", {"brokeradar"}, "Shows players who are broke on your map. They will have orange circles around them on the map. Really lets you see how impoverished GTA:O is.", function(on)
    broke_radar = on
    mod_uses("player", if on then 1 else -1)
    if not on then
        broke_radar = false
        mod_uses("player", -1)
        for plyr,blip in pairs(broke_blips) do
            HUD.SET_BLIP_ALPHA(blip, 0)
            broke_blips[plyr] = nil
        end
    end
end)

broke_threshold = 1000000
menu.slider(aphostile_root, "Broke threshold", {"brokethresh"}, "How much money a user must have to not be considered broke by the broke radar.", 100000, 1000000000, 1000000, 100000, function(s)
    broke_threshold = s
  end)


antioppressor = false
menu.toggle(ap_root, "Antioppressor", {"antioppressor"}, "Never see a fly again! Automatically deletes all active oppressor mkII\'s.", function(on)
    antioppressor = on
    mod_uses("player", if on then 1 else -1)
end)

noarmedvehs = false
menu.toggle(ap_root, "Delete armed vehicles", {"noarmedvehs"}, "Deletes any vehicle with a weapon. IMPORTANT: the game reports some false positives, ie considers a camera on a heli a \"gun\"..", function(on)
    noarmedvehs = on
    mod_uses("player", if on then 1 else -1)
end)

menu.action(ap_texts_root, "Send nudes", {"sendnudes"}, ";)", function(on_click)
    for k,pid in pairs(players.list(false, true, true)) do
        for i=1, #sexts do
            send_player_label_sms(sexts[i], pid)
            util.yield()
        end
        util.yield()
    end
end)

menu.toggle_loop(ap_texts_root, "Spam nudes", {"spamsexts"}, ";)", function(on)
    for k,pid in pairs(players.list(false, true, true)) do
        for i=1, #sexts do
            send_player_label_sms(sexts[i], pid)
            util.yield()
        end
        util.yield()
    end
end)

menu.action(ap_texts_root, "Spam random texts", {"spamlabels"}, "very toxic", function(on)
    for k,pid in pairs(players.list(false, true, true)) do
        for i=1, 1000 do
            send_player_label_sms(all_labels[math.random(1, #all_labels)], pid)
            util.yield()
        end
        util.yield()
    end
end)
kicktryhardnames = false
menu.toggle(online_root, "Auto-crash/kick tryhard names", {"kicktryhardnames"}, "Crashes, then kicks (for if the crash didn\'t succeed) those losers with only L\'s and I\'s in their name, in such a way that makes them hard to report. Fuck them.", function(on)
    kicktryhardnames = on
end)

kicktryhardkds = false
menu.toggle(online_root, "Auto-kick high-KD tryhards", {"kicktryhardkds"}, "Auto-kicks tryhards with an obsessively high KD. Might piss off a lot of modders, but so be it.", function(on)
    kicktryhardkds = on
end)

local kdthres = 6
menu.slider(online_root, "Auto-kick KD threshold", {"autokickkd"}, "Threshold players must pass in their KD to be autokicked, if enabled.", 1, 100, 6, 1, function(s)
    kdthres = 6
  end)

menu.action(aphostile_root, "Toast best mug target", {"best mug"}, "Toasts you the player with the most wallet money, so you can mug them nicely.", function(on_click)
    local ret = get_best_mug_target()
    if ret ~= nil then
        util.toast(ret)
    end
end)

menu.action(aphostile_root, "Announce best mug target", {"best mug"}, "Announces the player with the most wallet money, so people can mug them nicelyy.", function(on_click)
    local ret = get_best_mug_target()
    if ret ~= nil then
        chat.send_message(ret, false, true, true)
    end
end)

menu.action(aphostile_root, "Announce poorest player", {"poorestplayer"}, "Announces the player with the least bank and wallet money.", function(on_click)
    local ret = get_poorest_player()
    if ret ~= nil then
        chat.send_message(ret, false, true, true)
    end
end)
menu.action(apfriendly_root, "Announce richest player", {"richestplayer"}, "Announces the player with the most bank and wallet money.", function(on_click)
    local ret = get_richest_player()
    if ret ~= nil then
        chat.send_message(ret, false, true, true)
    end
end)



show_voicechatters = false
menu.toggle(online_root, "Show me who\'s using voicechat", {"showvoicechat"}, "Shows who is actually using GTA:O voice chat, in 2021. Which is likely to be nobody. So this is a bitch to test. but.", function(on)
    mod_uses("player", if on then 1 else -1)
end)

cur_names = {}
players.on_join(function(pid)
    ls_log("on_join func")
    ls_log("Player joining with pid " .. pid)
    if pid ~= players.user() then
        local name = PLAYER.GET_PLAYER_NAME(pid)
        ls_log("Adding pid " .. pid .. " to curnames with name " .. name)
        cur_names[pid+1] = name
        if kicktryhardnames then
            ls_log("kick tryhards")
            local _, Lcount = string.gsub(name, "L", "")
            local _, Icount = string.gsub(name, "I", "")
            local total = Lcount + Icount
            if total == #name then
                util.toast("Removing tryhard from your session (" .. name .. "). :)")
                menu.trigger_commands("crash" .. name)
                menu.trigger_commands("kick" .. name)
            end
        end
        if kicktryhardkds then
            local kd = players.get_kd(pid)
            if kd > kdthres then
                util.toast("Kicking " .. name .. " for having a KD past the threshold (" .. kd .. ").")
                menu.trigger_commands("kick" .. name)
            end
        end
    end
    ls_log("finished on_join func")
    ls_log("Setting up player actions for pid " .. pid)
    set_up_player_actions(pid)
end)
players.dispatch_on_join()

players.on_leave(function(pid)
    if broke_blips[pid] ~= nil then
        broke_blips[pid] = nil
        HUD.SET_BLIP_ALPHA(broke_blips[pid], 0)
    end
    ls_log("Player leaving with pid " .. pid)
    if pid ~= players.user() then
        --pass?
    end
end)


players_thread = util.create_thread(function (thr)
    while true do
        if player_uses > 0 then
            if show_updates then
                util.toast("Player pool is being updated")
            end
            all_players = players.list(true, true, true)
            for k,pid in pairs(all_players) do
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
                    ls_log("noarmedvehs")
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
                            HUD.SET_BLIP_ALPHA(blip, 0)
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
menu.toggle(lancescript_root, "Debug", {"lancescriptdebug"}, "Spams console and toasts with useful debug info.", function(on)
    ls_debug = on
end, false)

-- CREDITS
lancescript_credits = menu.list(lancescript_root, "Credits", {"lancescriptcredits"}, "")
menu.action(lancescript_credits, "Jerrrry123", {}, "Creating a (accepted) PR that optimized LanceScript and cut down on code, also fixed and improved some features.", function(on_click) end)

-- SCRIPT IS "FINISHED LOADING"
is_loading = false

-- ## MAIN TICK LOOP ## --
while true do
    HUD.DISPLAY_RADAR(true)
    for k,v in pairs(ped_flags) do
        if v ~= nil and v then
            PED.SET_PED_CONFIG_FLAG(players.user_ped(), k, true)
        end
    end
    player_cur_car = entities.get_user_vehicle_as_handle()
    -- MY VEHICLE LOOP SHIT
    if mph_plate then
        if player_cur_car ~= 0 then
            if mph_unit == "kph" then
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
        ls_log("dowblock check")
        if dow_block == 0 or not ENTITY.DOES_ENTITY_EXIST(dow_block) then
            ls_log("dowblock made")
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
        ls_log("move dowblock to 0 0 0")
        ENTITY.SET_ENTITY_COORDS_NO_OFFSET(dow_block, 0, 0, 0, false, false, false)
    end

    if walkonwater then
        ls_log("walkonwater loop")
        local car = PED.GET_VEHICLE_PED_IS_IN(players.user_ped(), false)
        if car == 0 then
            local pos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(players.user_ped(), 0.0, 2.0, 0.0)
            -- we need to offset this because otherwise the player keeps diving off the thing, like a fucking dumbass
            -- ht isnt actually used here, but im allocating some memory anyways to prevent a possible crash, probably. idk im no computer engineer
            ls_log("alloc 4 bytes, walkonwater")
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
        ls_log("driveonwater loop")
        if player_cur_car ~= 0 then
            local pos = ENTITY.GET_ENTITY_COORDS(player_cur_car, true)
            -- ht isnt actually used here, but im allocating some memory anyways to prevent a possible crash, probably. idk im no computer engineer
            ls_log("alloc 4 bytes, driveonwater")
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
        ls_log("driveonair loop")
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
        ls_log("aim info loop")
        local info = get_aim_info()
        if info['ent'] ~= 0 then
            local text = "Hash: " .. info['hash'] .. "\nEntity: " .. info['ent'] .. "\nHealth: " .. info['health'] .. "\nType: " .. info['type'] .. "\nSpeed: " .. info['speed']
            directx.draw_text(0.5, 0.3, text, 5, 0.5, white, true)
        end
    end

    if gun_stealer then
        ls_log("stealer gun")
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
        ls_log("driver gun")
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
        ls_log("tesla ped loop")
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
            HUD.SET_BLIP_ALPHA(tesla_blip, 0)
        end
    end
    util.yield()
end

