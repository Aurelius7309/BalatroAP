--- STEAMODDED HEADER
--- MOD_NAME: Randomizer
--- MOD_ID: Rando
--- MOD_AUTHOR: [Burndi, SpaD_Overolls, Myst, Silvris]
--- MOD_DESCRIPTION: Archipelago
----------------------------------------------
------------MOD CODE -------------------------
G.AP = {
    APAddress = "archipelago.gg",
    APPort = 38281,
    APSlot = "Player1",
    APPassword = "",
    id_offset = 5606000
}

G.AP.location_id_to_item_name = {}

G.AP.this_mod = SMODS.current_mod

NFS.load(G.AP.this_mod.path .. "ap_connection.lua")()
NFS.load(G.AP.this_mod.path .. "utils.lua")()

json = NFS.load(G.AP.this_mod.path .. "json.lua")()
AP = require('lua-apclientpp')

local isInProfileTabCreation = false
local isInProfileOptionCreation = false
local unloadAPProfile = false
local foreignDeathlink = false
local ap_profile_delete = false
local ap_items_in_shop = 0

local deck_list = {}
deck_list[0] = 'Red Deck'
deck_list[1] = 'Blue Deck'
deck_list[2] = 'Yellow Deck'
deck_list[3] = 'Green Deck'
deck_list[4] = 'Black Deck'
deck_list[5] = 'Magic Deck'
deck_list[6] = 'Nebula Deck'
deck_list[7] = 'Ghost Deck'
deck_list[8] = 'Abandoned Deck'
deck_list[9] = 'Checkered Deck'
deck_list[10] = 'Zodiac Deck'
deck_list[11] = 'Painted Deck'
deck_list[12] = 'Anaglyph Deck'
deck_list[13] = 'Plasma Deck'
deck_list[14] = 'Erratic Deck'

G.AP.profile_Id = -1
G.AP.GameObjectInit = false

--stake cursor used for AP logic
G.viewed_stake_act = {}
G.viewed_stake_act[1] = 1
G.viewed_stake_act[2] = 1

-- true if the profile was selected and loaded
function isAPProfileLoaded()
    return G.SETTINGS and G.AP and G.SETTINGS.profile == G.AP.profile_Id
end

-- true if the profile is selected in profile selection, does not have to be loaded yet
function isAPProfileSelected()
    return G.focused_profile == G.AP.profile_Id
end

G.FUNCS.can_APConnect = function(e)
    if (G.APClient) then
        e.config.button = nil
        e.config.colour = G.C.UI.BACKGROUND_INACTIVE
    else
        e.config.button = 'APConnect'
        e.config.colour = G.C.RED
    end
end

-- gets called when connection wants to be established. Also saves Connection info in json
G.FUNCS.APConnect = function(e)
    local APInfo = json.encode({
        APAddress = G.AP.APAddress,
        APPort = G.AP.APPort,
        APSlot = G.AP.APSlot,
        APPassword = G.AP.APPassword
    })
    NFS.write('APSettings.json', APInfo)

    APConnect()
end

-- gets called when connection wants to be ended (for example when selecting non AP profile)
G.FUNCS.APDisconnect = function()
    G.APClient = nil
    collectgarbage("collect")
    unloadAPProfile = true

end

-- Initialize AP Buffs

local init_game_objectRef = Game.init_game_object
function Game:init_game_object()
    local init_game_object = init_game_objectRef(self)

    if isAPProfileLoaded() then

        init_game_object.starting_params.hands = init_game_object.starting_params.hands +
                                                     (G.PROFILES[G.AP.profile_Id]["bonushands"] or 0)

        init_game_object.starting_params.discards = init_game_object.starting_params.discards +
                                                        (G.PROFILES[G.AP.profile_Id]["bonusdiscards"] or 0)

        init_game_object.starting_params.dollars = init_game_object.starting_params.dollars +
                                                       (G.PROFILES[G.AP.profile_Id]["bonusstartingmoney"] or 0)

        init_game_object.starting_params.hand_size = init_game_object.starting_params.hand_size +
                                                         (G.PROFILES[G.AP.profile_Id]["bonushandsize"] or 0)

        init_game_object.interest_cap = init_game_object.interest_cap +
                                            (G.PROFILES[G.AP.profile_Id]["maxinterest"] * 5 or 0)

        init_game_object.starting_params.joker_slots = init_game_object.starting_params.joker_slots +
                                                           (G.PROFILES[G.AP.profile_Id]["bonusjoker"] or 0)

        init_game_object.starting_params.consumable_slots = init_game_object.starting_params.consumable_slots +
                                                                (G.PROFILES[G.AP.profile_Id]["bonusconsumable"] or 0)

    end

    foreignDeathlink = false
    return init_game_object
end

-- DeathLink 

G.FUNCS.die = function()

    if G.STAGE == G.STAGES.RUN and G.AP.slot_data and G.AP.slot_data.deathlink then

        foreignDeathlink = true
        -- G.SETTINGS.screenshake = 300
        G.STATE = G.STATES.GAME_OVER
        if not G.GAME.won and not G.GAME.seeded and not G.GAME.challenge then
            G.PROFILES[G.SETTINGS.profile].high_scores.current_streak.amt = 0
        end
        G:save_settings()
        G.FILE_HANDLER.force = true
        G.STATE_COMPLETE = false
    end
end

function split_text_to_lines(text)
    local lines = {}
    local count = 0
    for word in text:gmatch("%S+") do
        if count % 4 == 0 then
            lines[#lines + 1] = ""
        end
        count = count + 1
        lines[#lines] = lines[#lines] .. " " .. word
    end

    return lines
end

-- jimbo yaps about deathlink cause

local speech_bubbleref = G.UIDEF.speech_bubble
function G.UIDEF.speech_bubble(text_key, loc_vars)
    if isAPProfileLoaded() and
        (not G.GAME.game_over_by_deathlink and G.AP.death_link_cause and G.AP.death_link_cause ~= "unknown" and loc_vars and
            loc_vars.quip) then
        -- split cause into chunks
        local lines = split_text_to_lines(G.AP.death_link_cause)

        G.localization.quips_parsed.ap_death = {
            multi_line = true
        }
        for k, v in ipairs(lines) do
            G.localization.quips_parsed.ap_death[k] = loc_parse_string(v)
        end

        local text = {}
        localize {
            type = 'quips',
            key = 'ap_death',
            vars = {},
            nodes = text
        }
        local row = {}
        for k, v in ipairs(text) do
            row[#row + 1] = {
                n = G.UIT.R,
                config = {
                    align = "cl"
                },
                nodes = v
            }
        end
        local t = {
            n = G.UIT.ROOT,
            config = {
                align = "cm",
                minh = 1,
                r = 0.3,
                padding = 0.07,
                minw = 1,
                colour = G.C.JOKER_GREY,
                shadow = true
            },
            nodes = {{
                n = G.UIT.C,
                config = {
                    align = "cm",
                    minh = 1,
                    r = 0.2,
                    padding = 0.1,
                    minw = 1,
                    colour = G.C.WHITE
                },
                nodes = {{
                    n = G.UIT.C,
                    config = {
                        align = "cm",
                        minh = 1,
                        r = 0.2,
                        padding = 0.03,
                        minw = 1,
                        colour = G.C.WHITE
                    },
                    nodes = row
                }}
            }}
        }
        return t
    end
    return speech_bubbleref(text_key, loc_vars)
end

-- send out deathlink

function sendDeathLinkBounce(cause, source)
    cause = cause or "Balatro"
    source = source or G.AP.APSlot or "BalatroPlayer"
    local time = G.APClient:get_server_time()
    sendDebugMessage("AP:sendDeathLinkBounce " .. tostring(time) .. " " .. cause .. " " .. source)
    local res = G.APClient:Bounce({
        time = time,
        cause = cause,
        source = source
    }, {}, {}, {"DeathLink"})
    sendDebugMessage("AP:sendDeathLinkBounce " .. tostring(G.APClient))
    sendDebugMessage("AP:sendDeathLinkBounce " .. tostring(res))
end

local update_game_overRef = Game.update_game_over
function Game:update_game_over(dt)
    -- only sends deathlink if run ended before and during ante 8
    -- also checks if run is over because of deathlink coming in (not sure if necessary)
    if isAPProfileLoaded() and G.AP.slot_data and G.AP.slot_data.deathlink and G.GAME.round_resets.ante <=
        G.GAME.win_ante and not foreignDeathlink and not G.GAME.game_over_by_deathlink then
        sendDeathLinkBounce("Run ended at ante " .. G.GAME.round_resets.ante)
        G.GAME.game_over_by_deathlink = true
    end
    return update_game_overRef(self, dt)
end

-- Profile interface

local create_tabsRef = create_tabs
function create_tabs(args)
    -- when profile interface is created, add archipelago tab 
    if isInProfileTabCreation then
        args.tabs[G.AP.profile_Id] = {
            label = "ARCHIPELAGO",
            chosen = G.focused_profile == G.AP.profile_Id,
            tab_definition_function = G.UIDEF.profile_option,
            tab_definition_function_args = G.AP.profile_Id
        }
    end

    local create_tabs = create_tabsRef(args)

    return create_tabs
end

local profile_selectRef = G.UIDEF.profile_select
function G.UIDEF.profile_select()
    isInProfileTabCreation = true

    local profile_select = profile_selectRef()

    isInProfileTabCreation = false
    return profile_select
end

local create_text_inputRef = create_text_input
function create_text_input(args)
    local create_text_input = create_text_inputRef(args)

    if isInProfileOptionCreation then

        create_text_input['config']['draw_layer'] = nil
        create_text_input['nodes'][1]['config']['draw_layer'] = nil

        local ui_letters = create_text_input['nodes'][1]['nodes'][1]['nodes'][1]['nodes'][1]
        -- sendDebugMessage("Is not null: " .. tostring(#ui_letters))

        if #ui_letters > 0 then
            ui_letters[#ui_letters]['config']['id'] = 'position_' .. args.prompt_text
        end
    end

    return create_text_input
end

local profile_optionRef = G.UIDEF.profile_option
function G.UIDEF.profile_option(_profile)
    G.focused_profile = _profile
    if isAPProfileSelected() then -- AP profile tab code

        isInProfileOptionCreation = true
        local t = {
            n = G.UIT.ROOT,
            config = {
                align = 'cm',
                colour = G.C.CLEAR
            },
            nodes = {{
                n = G.UIT.R,
                config = {
                    align = 'cm',
                    padding = 0.1,
                    minh = 0.8
                },
                nodes = {((_profile == G.SETTINGS.profile) or not profile_data) and {
                    n = G.UIT.R,
                    config = {
                        align = "cm"
                    },
                    nodes = {create_text_input({
                        w = 4,
                        max_length = 35,
                        prompt_text = 'Server Address',
                        ref_table = G.AP,
                        ref_value = 'APAddress',
                        extended_corpus = true,
                        keyboard_offset = 1,
                        callback = function()
                            -- code for when enter is hit (?)
                        end
                    }), create_text_input({
                        w = 4,
                        max_length = 35,
                        prompt_text = 'PORT',
                        ref_table = G.AP,
                        ref_value = 'APPort',
                        extended_corpus = false,
                        keyboard_offset = 1,
                        callback = function()
                            -- code for when enter is hit (?)
                        end
                    })}
                }}
            }, {
                n = G.UIT.R,
                config = {
                    align = 'cm',
                    padding = 0.1,
                    minh = 0.8
                },
                nodes = {((_profile == G.SETTINGS.profile) or not profile_data) and {
                    n = G.UIT.R,
                    config = {
                        align = "cm"
                    },
                    nodes = {create_text_input({
                        w = 4,
                        max_length = 35,
                        prompt_text = 'Slot name',
                        ref_table = G.AP,
                        ref_value = 'APSlot',
                        extended_corpus = true,
                        keyboard_offset = 1,
                        callback = function()
                            -- code for when enter is hit (?)
                        end
                    }), create_text_input({
                        w = 4,
                        max_length = 35,
                        prompt_text = 'Password',
                        ref_table = G.AP,
                        ref_value = 'APPassword',
                        extended_corpus = true,
                        keyboard_offset = 1,
                        callback = function()
                            -- code for when enter is hit (?)
                        end
                    })}
                }}
            }, UIBox_button({
                button = "APConnect",
                label = {"Connect"},
                minw = 3,
                func = "can_APConnect"
            }), {
                n = G.UIT.R,
                config = {
                    align = "cm",
                    padding = 0,
                    minh = 0.7
                },
                nodes = {{
                    n = G.UIT.R,
                    config = {
                        align = "cm",
                        minw = 3,
                        maxw = 4,
                        minh = 0.6,
                        padding = 0.2,
                        r = 0.1,
                        hover = true,
                        colour = G.C.RED,
                        func = 'can_delete_AP_profile',
                        button = "delete_profile",
                        shadow = true,
                        focus_args = {
                            nav = 'wide'
                        }
                    },
                    nodes = {{
                        n = G.UIT.T,
                        config = {
                            text = _profile == G.SETTINGS.profile and localize('b_reset_profile') or
                                localize('b_delete_profile'),
                            scale = 0.3,
                            colour = G.C.UI.TEXT_LIGHT
                        }
                    }}
                }}
            }, {
                n = G.UIT.R,
                config = {
                    align = "cm",
                    padding = 0
                },
                nodes = {{
                    n = G.UIT.T,
                    config = {
                        id = 'warning_text',
                        text = localize('ph_click_confirm'),
                        scale = 0.4,
                        colour = G.C.CLEAR
                    }
                }}
            }}
        }
        isInProfileOptionCreation = false
        return t

    else -- if not AP profile behave normally
        if not isAPProfileLoaded() then
            G.APClient = nil
            collectgarbage("collect")
        end
        local profile_option = profile_optionRef(_profile)
        return profile_option
    end

end

-- game changes

local game_updateRef = Game.update
function Game:update(dt)
    local game_update = game_updateRef(self, dt)
    if G.APClient ~= nil then
        G.APClient:poll()
    end

    if G.STAGE == G.STAGES.MAIN_MENU and foreignDeathlink then

        foreignDeathlink = false
    end

    return game_update
end

local game_drawRef = Game.draw
function Game:draw()
    local game_draw = game_drawRef(self)
    if G and G.STAGES and G.STAGE == G.STAGES.MAIN_MENU then
        if G.APClient ~= nil then
            if G.APClient:get_state() == AP.State.SLOT_CONNECTED then
                love.graphics.print("Connected to Archipelago at " .. G.AP.APAddress .. ":" .. G.AP.APPort .. " as " ..
                                        G.AP.APSlot, 10, 30)

                if G.AP.goal and G.AP.GameObjectInit then
                    -- beat # of decks
                    if G.AP.goal == 0 then
                        -- calculating this every frame is stupid
                        local deck_wins = 0
                        for k, v in pairs(G.P_CENTERS) do
                            if string.find(tostring(k), '^b_') then
                                if G.PROFILES[G.SETTINGS.profile] and G.PROFILES[G.SETTINGS.profile].deck_usage and
                                    G.PROFILES[G.SETTINGS.profile].deck_usage[k] and
                                    G.PROFILES[G.SETTINGS.profile].deck_usage[k].wins and
                                    #G.PROFILES[G.SETTINGS.profile].deck_usage[k].wins > 0 then
                                    deck_wins = deck_wins + 1
                                end
                            end
                        end
                        love.graphics.print("Goal: Beat " .. G.AP.slot_data.decks_win_goal ..
                                                " Decks. You already beat " .. tostring(deck_wins) .. " Decks.", 10, 60)
                        -- unlock # of jokers
                    elseif G.AP.goal == 1 then
                        local unlocked_jokers = get_unlocked_jokers()
                        love.graphics.print("Goal: Unlock " .. G.AP.slot_data.jokers_unlock_goal ..
                                                " Jokers. You already unlocked " .. tostring(unlocked_jokers) ..
                                                " Jokers.", 10, 60)

                        -- beat specific ante
                    elseif G.AP.goal == 2 then
                        love.graphics.print("Goal: Beat Ante " .. G.AP.slot_data.ante_win_goal, 10, 60)
                    end
                end
            else
                love.graphics.print("Connecting to Archipelago at " .. G.AP.APAddress .. ":" .. G.AP.APPort, 10, 30)
            end

        else
            love.graphics.print("Not connected to Archipelago.", 10, 30)
        end
    end

    return game_draw
end

-- load APSettings when opening Profile Select
-- also create new profile when first loading (might have to move this somewhere more fitting)

local game_load_profileRef = Game.load_profile
function Game:load_profile(_profile)

    if unloadAPProfile then
        _profile = 1
        unloadAPProfile = false
    end
    ap_profile_delete = false

    if G.AP.profile_Id == -1 then
        G.AP.profile_Id = #G.PROFILES + 1
        G.PROFILES[G.AP.profile_Id] = {}
        sendDebugMessage("Created AP Profile in Slot " .. tostring(G.AP.profile_Id))
    end

    local game_load_profile = game_load_profileRef(self, _profile)

    local APSettings = NFS.read('APSettings.json')

    if APSettings ~= nil then
        APSettings = json.decode(APSettings)
        if APSettings ~= nil then
            G.AP.APSlot = APSettings['APSlot'] or G.AP.APSlot
            G.AP.APAddress = APSettings['APAddress'] or G.AP.APAddress
            G.AP.APPort = APSettings['APPort'] or G.AP.APPort
            G.AP.APPassword = APSettings['APPassword'] or G.AP.APPassword
        end
    end

    return game_load_profile
end

local standard_deck = nil

local back_initRef = Back.init
function Back:init(selected_back)

    if isAPProfileLoaded() and not selected_back then
        selected_back = G.P_CENTERS[standard_deck or 'b_red']
    end
    return back_initRef(self, selected_back)
end
-- unlock Items based on APItems

G.FUNCS.AP_unlock_item = function(item)
    G:save_notify(item)
    table.sort(G.P_CENTER_POOLS["Back"], function(a, b)
        return (a.order - (a.unlocked and 100 or 0)) < (b.order - (b.unlocked and 100 or 0))
    end)
    G:save_progress()
    if item.set == 'Back' then
        discover_card(item)
    end

    if item.set == 'Joker' and G.DISCOVER_TALLIES and G.DISCOVER_TALLIES.jokers and G.DISCOVER_TALLIES.jokers.tally then
        G.DISCOVER_TALLIES.jokers.tally = G.DISCOVER_TALLIES.jokers.tally + 1
    end

    G.FILE_HANDLER.force = true
    notify_alert(item.key, item.set)
end

local game_init_item_prototypesRef = Game.init_item_prototypes
function Game:init_item_prototypes()
    local game_init_item_prototypes = game_init_item_prototypesRef(self)

    if isAPProfileLoaded() then
        -- Locked text (this system might have to be largely overhauled, can't be bothered tho 😀)
        G.localization.descriptions["Booster"] = {}
        -- G.localization.descriptions["Tarot"] = {}
        -- G.localization.descriptions["Planet"] = {}
        -- G.localization.descriptions["Spectral"] = {}
        for g_k, group in pairs(G.localization) do
            if g_k == 'descriptions' then
                for grpkey, set in pairs(group) do
                    for x, center in pairs(set) do

                        if string.find(tostring(x), '^b_') or string.find(tostring(x), '^j_') or
                            string.find(tostring(x), '^v_') or
                            (string.find(tostring(x), '^c_') and not string.find(tostring(x), '^c_base')) or
                            string.find(tostring(x), '^p_') then

                            center.demo_locked = {}
                            center.demo_locked[1] = loc_parse_string("AP Item")

                            center.deck_locked_win = {}
                            center.deck_locked_win[1] = loc_parse_string("AP Item")

                            center.unlock_parsed = {}
                            center.unlock_parsed[1] = loc_parse_string("AP Item")

                            if string.find(tostring(x), '^p_') then
                                G.localization.descriptions["Booster"][x] = center
                            end
                        end

                    end
                end
            end
        end

        for k, v in pairs(G.AP.JokerQueue) do
            G.PROFILES[G.AP.profile_Id]["jokers"][k] = true
        end

        for k, v in pairs(G.AP.BackQueue) do
            G.PROFILES[G.AP.profile_Id]["backs"][k] = true
        end

        for k, v in pairs(G.AP.VoucherQueue) do
            G.PROFILES[G.AP.profile_Id]["vouchers"][k] = true
        end

        for k, v in pairs(G.AP.PackQueue) do
            G.PROFILES[G.AP.profile_Id]["packs"][k] = true
        end

        for k, v in pairs(G.AP.ConsumableQueue) do
            G.PROFILES[G.AP.profile_Id]["consumables"][k] = true
        end

        self.P_LOCKED = {}
        for k, v in pairs(self.P_CENTERS) do
            -- for jokers
            if string.find(k, '^j_') then
                v.unlocked = true
                v.discovered = true
                v.hidden = false
                v.ap_unlocked = false
                if G.PROFILES[G.AP.profile_Id]["jokers"][v.name] ~= nil then
                    -- v.unlocked = true
                    -- v.discovered = true
                    -- v.hidden = false
                    v.ap_unlocked = true

                    if (G.AP.JokerQueue[v] == true) then
                        G.FUNCS.AP_unlock_item(v)
                    end
                end
                -- for backs (decks)
            elseif string.find(k, '^b_') then
                v.unlocked = false
                v.unlock_condition = nil
                if G.PROFILES[G.AP.profile_Id]["backs"][v.name] ~= nil then
                    v.unlocked = true
                    v.discovered = true
                    v.hidden = false
                    if (G.AP.BackQueue[v] == true) then
                        G.FUNCS.AP_unlock_item(v)
                    end
                end

                if not tableContains(G.AP.slot_data.included_decks, k) then
                    SMODS.Back:take_ownership(k, {}):delete()
                elseif not standard_deck then
                    standard_deck = k
                end

		-- create (or fix) deck_usage (for stake unlocks)
		if not G.PROFILES[G.AP.profile_Id].deck_usage then G.PROFILES[G.AP.profile_Id].deck_usage = {} end
		if not G.PROFILES[G.AP.profile_Id].deck_usage[k] then G.PROFILES[G.AP.profile_Id].deck_usage[k] = {} end
		if not G.PROFILES[G.AP.profile_Id].deck_usage[k].count then G.PROFILES[G.AP.profile_Id].deck_usage[k].count = 0 end
		if not G.PROFILES[G.AP.profile_Id].deck_usage[k].wins then G.PROFILES[G.AP.profile_Id].deck_usage[k].wins = {} end
		if not G.PROFILES[G.AP.profile_Id].deck_usage[k].losses then G.PROFILES[G.AP.profile_Id].deck_usage[k].losses = {} end
		if not G.PROFILES[G.AP.profile_Id].deck_usage[k].stake_unlocks then
			G.PROFILES[G.AP.profile_Id].deck_usage[k].stake_unlocks = {}
			for i = 1, 8, 1 do
				G.PROFILES[G.AP.profile_Id].deck_usage[k].stake_unlocks[i] = false
			end
		end

                -- for vouchers
            elseif string.find(k, '^v_') and not string.find(k, '^v_rand_ap_item') then
                v.unlocked = false
                if G.PROFILES[G.AP.profile_Id]["vouchers"][v.name] ~= nil then
                    -- progressive vouchers
                    if v.requires then
                        if (not G.P_CENTERS[v.requires[1]].unlocked) then
                            G.P_CENTERS[v.requires[1]].nextVoucher = v
                            v = G.P_CENTERS[v.requires[1]]
                        end
                    elseif v.nextVoucher then
                        v = v.nextVoucher
                    end

                    v.unlocked = true
                    v.discovered = true
                    v.hidden = false
                    if (G.AP.VoucherQueue[v] == true) then
                        G.FUNCS.AP_unlock_item(v)
                    end
                end
                -- for packs
            elseif string.find(k, '^p_') then
                v.unlocked = false
                if G.PROFILES[G.AP.profile_Id]["packs"][v.name] ~= nil then
                    v.unlocked = true
                    v.discovered = true
                    v.hidden = false
                    if (G.AP.PackQueue[v] == true) then
                        G.FUNCS.AP_unlock_item(v)
                    end
                end
                -- for consumables

            elseif string.find(k, '^c_') and not string.find(k, '^c_base') then
                v.unlocked = false

                if G.PROFILES[G.AP.profile_Id]["consumables"][v.name] ~= nil then
                    v.unlocked = true
                    v.discovered = true
                    v.hidden = false
                    if (G.AP.ConsumableQueue[v] == true) then
                        G.FUNCS.AP_unlock_item(v)
                    end
                end
            end

            v.unlock_condition = v.unlock_condition or {}

            if (v.unlocked ~= nil and v.unlocked == false) or v.ap_unlocked == false then
                v.discovered = v.unlocked
                v.hidden = not v.unlocked
                self.P_LOCKED[#self.P_LOCKED + 1] = v
            end

        end

	-- Handle global stake unlock save data
	if not G.PROFILES[G.AP.profile_Id].stake_unlocks then
		G.PROFILES[G.AP.profile_Id].stake_unlocks = {}
		for i = 1, 8, 1 do
			G.PROFILES[G.AP.profile_Id].stake_unlocks[i] = false
		end
		-- G.PROFILES[G.AP.profile_Id].stake_unlocks[1] = true
		-- ^ uncomment to force the first stake to be always open 
	end
	
        -- Handle Queued Bonus stuff

        for k, v in pairs(G.AP.BonusQueue) do
            if (not G.PROFILES[G.AP.profile_Id]["received_indeces"][v.idx]) then

                if (v.type == "bonusdiscards") then
                    G.PROFILES[G.AP.profile_Id]["bonusdiscards"] =
                        (G.PROFILES[G.AP.profile_Id]["bonusdiscards"] or 0) + 1
                elseif (v.type == "bonusstartingmoney") then
                    G.PROFILES[G.AP.profile_Id]["bonusstartingmoney"] =
                        (G.PROFILES[G.AP.profile_Id]["bonusstartingmoney"] or 0) + 1
                elseif (v.type == "bonushands") then
                    G.PROFILES[G.AP.profile_Id]["bonushands"] = (G.PROFILES[G.AP.profile_Id]["bonushands"] or 0) + 1

                elseif (v.type == "bonushandsize") then
                    G.PROFILES[G.AP.profile_Id]["bonushandsize"] =
                        (G.PROFILES[G.AP.profile_Id]["bonushandsize"] or 0) + 1
                elseif (v.type == "maxinterest") then
                    G.PROFILES[G.AP.profile_Id]["maxinterest"] = (G.PROFILES[G.AP.profile_Id]["maxinterest"] or 0) + 1

                elseif (v.type == "bonusjoker") then
                    G.PROFILES[G.AP.profile_Id]["bonusjoker"] = (G.PROFILES[G.AP.profile_Id]["bonusjoker"] or 0) + 1

                elseif (v.type == "bonusconsumable") then
                    G.PROFILES[G.AP.profile_Id]["bonusconsumable"] =
                        (G.PROFILES[G.AP.profile_Id]["bonusconsumable"] or 0) + 1
                end

                G.PROFILES[G.AP.profile_Id]["received_indeces"][v.idx] = true
            end
        end

        -- remove queued items
        G.AP.BonusQueue = {}
        G.AP.BackQueue = {}
        G.AP.VoucherQueue = {}
        G.AP.JokerQueue = {}
        G.AP.PackQueue = {}
        G.AP.ConsumableQueue = {}
        G.AP.GameObjectInit = true

        G.FUNCS.initialize_shop_items()

        self.P_CENTERS['b_red'] = self.P_CENTERS[standard_deck]
    end
    return game_init_item_prototypes
end

-- handle stakes

-- reinsert the stakes in the desired order, removing the modded ones
function init_AP_stakes()
	
	local _defaul_stakes = {}
	_defaul_stakes[1] = {
        name = "White Stake",
        key = "stake_white",
	original_key = "white",
        applied_stakes = {},
		atlas = "chips",
        pos = { x = 0, y = 0 },
        sticker_pos = { x = 1, y = 0 },
        colour = G.C.WHITE,
	shiny = false,
        loc_txt = {}
    }
	
	_defaul_stakes[2] = {
        name = "Red Stake",
        key = "stake_red",
	original_key = "red",
        applied_stakes = { "white" },
	atlas = "chips",
        pos = { x = 1, y = 0 },
        sticker_pos = { x = 2, y = 0 },
        modifiers = function()
            G.GAME.modifiers.no_blind_reward = G.GAME.modifiers.no_blind_reward or {}
            G.GAME.modifiers.no_blind_reward.Small = true
        end,
        colour = G.C.RED,
	shiny = false,
        loc_txt = {}
    }
	
	_defaul_stakes[3] = {
        name = "Green Stake",
        key = "stake_green",
	original_key = "green",
        applied_stakes = { "red" },
	atlas = "chips",
        pos = { x = 2, y = 0 },
        sticker_pos = { x = 3, y = 0 },
        modifiers = function()
            G.GAME.modifiers.scaling = math.max(G.GAME.modifiers.scaling or 0, 2)
        end,
        colour = G.C.GREEN,
	shiny = false,
        loc_txt = {}
    }
	
	_defaul_stakes[4] = {
        name = "Black Stake",
        key = "stake_black",
	original_key = "black",
        applied_stakes = { "green" },
	atlas = "chips",
        pos = { x = 4, y = 0 },
        sticker_pos = { x = 0, y = 1 },
        modifiers = function()
            G.GAME.modifiers.enable_eternals_in_shop = true
        end,
        colour = G.C.BLACK,
	shiny = false,
        loc_txt = {}
    }
	
	_defaul_stakes[5] = {
        name = "Blue Stake",
	key = "stake_blue",
        original_key = "blue",
        applied_stakes = { "black" },
	atlas = "chips",
        pos = { x = 3, y = 0 },
        sticker_pos = { x = 4, y = 0 },
        modifiers = function()
            G.GAME.starting_params.discards = G.GAME.starting_params.discards - 1
        end,
        colour = G.C.BLUE,
		shiny = false,
        loc_txt = {}
    }
	
	_defaul_stakes[6] = {
        name = "Purple Stake",
	key = "stake_purple",
        original_key = "purple",
        applied_stakes = { "blue" },
	atlas = "chips",
        pos = { x = 0, y = 1 },
        sticker_pos = { x = 1, y = 1 },
        modifiers = function()
            G.GAME.modifiers.scaling = math.max(G.GAME.modifiers.scaling or 0, 3)
        end,
        colour = G.C.PURPLE,
	shiny = false,
        loc_txt = {}
    }
	
	_defaul_stakes[7] = {
        name = "Orange Stake",
        key = "stake_orange",
	original_key = "orange",
        applied_stakes = { "purple" },
	atlas = "chips",
        pos = { x = 1, y = 1 },
        sticker_pos = { x = 2, y = 1 },
        modifiers = function()
            G.GAME.modifiers.enable_perishables_in_shop = true
        end,
        colour = G.C.ORANGE,
	shiny = false,
        loc_txt = {}
    }
	
	_defaul_stakes[8] = {
        name = "Gold Stake",
	key = "stake_gold",
        original_key = "gold",
        applied_stakes = { "orange" },
	atlas = "chips",
        pos = { x = 2, y = 1 },
        sticker_pos = { x = 3, y = 1 },
        modifiers = function()
            G.GAME.modifiers.enable_rentals_in_shop = true
        end,
        colour = G.C.GOLD,
        shiny = true,
        loc_txt = {}
    }
	
	-- create a copy of included stake list
	local _stake_list = {}
	for i = 1, #G.AP.slot_data.included_stakes, 1 do
		_stake_list[i] = G.AP.slot_data.included_stakes[i]
	end
	
	-- insert unused stakes at the end of the list
	-- (we must have all 8 stakes existing, otherwise
	-- the game crashes when trying to apply a nonexistent stake)
	--      (^ could be solved by rerouting the applied stakes)
	--      (but that changes the difficulties of the stakes)
	for i = 1, 8, 1 do
		if not tableContains(_stake_list, i) then
			_stake_list[#_stake_list+1] = i
		end
	end


	for i = 1, 8, 1 do
		-- just copy these values
		G.P_CENTER_POOLS.Stake[i].name = _defaul_stakes[_stake_list[i]].name
		G.P_CENTER_POOLS.Stake[i].key = _defaul_stakes[_stake_list[i]].key
		G.P_CENTER_POOLS.Stake[i].original_key = _defaul_stakes[_stake_list[i]].original_key
		G.P_CENTER_POOLS.Stake[i].applied_stakes = _defaul_stakes[_stake_list[i]].applied_stakes
		G.P_CENTER_POOLS.Stake[i].atlas = _defaul_stakes[_stake_list[i]].atlas
		G.P_CENTER_POOLS.Stake[i].pos = _defaul_stakes[_stake_list[i]].pos
		G.P_CENTER_POOLS.Stake[i].sticker_pos = _defaul_stakes[_stake_list[i]].sticker_pos
		G.P_CENTER_POOLS.Stake[i].modifiers = _defaul_stakes[_stake_list[i]].modifiers
		G.P_CENTER_POOLS.Stake[i].colour = _defaul_stakes[_stake_list[i]].colour
		G.P_CENTER_POOLS.Stake[i].shiny = _defaul_stakes[_stake_list[i]].shiny
		G.P_CENTER_POOLS.Stake[i].loc_txt = _defaul_stakes[_stake_list[i]].loc_txt
		G.P_CENTER_POOLS.Stake[i].stake_level = _stake_list[i]
		
		-- read global unlock from the profile
		G.P_CENTER_POOLS.Stake[i].unlocked = G.PROFILES[G.AP.profile_Id].stake_unlocks[i]
		
		-- set the unlocked stake data if not last in/outside of included list
		G.P_CENTER_POOLS.Stake[i].unlocked_stake = i < #G.AP.slot_data.included_stakes and _defaul_stakes[_stake_list[i+1]].original_key or nil
	end
	
	--remove excess stakes generated by other mods
	while #G.P_CENTER_POOLS.Stake > 8 do
		table.remove(G.P_CENTER_POOLS.Stake, #G.P_CENTER_POOLS.Stake)
	end
	
	--update the colors
	for i = 1, #G.P_CENTER_POOLS.Stake do
		G.C.STAKES[i] = G.P_CENTER_POOLS.Stake[i].colour or G.C.WHITE
	end

end

function check_stake_unlock(_stake, _deck_key)
	-- [Mode 0] all unlocked mode
	if G.AP.slot_data.stake_unlock_mode == tonumber(0) then return true end
	
	-- [Mode 1] linear progression (vanilla)
	-- (beating a stake unlocks the next one in the list)
	-- (per deck)
	if G.AP.slot_data.stake_unlock_mode == tonumber(1) then
		if G.PROFILES[G.SETTINGS.profile].deck_usage[_deck_key] then
			local _stake_progress = 0
			for k, v in pairs(G.PROFILES[G.SETTINGS.profile].deck_usage[_deck_key].wins) do
				_stake_progress = math.max(_stake_progress, k)
			end
			
			if _stake <= _stake_progress+1 then return true end 
		elseif _stake == 1 then return true end
		
		return false
	end
	
	-- [Mode 2] global unlocks
	-- (stakes are unlocked if their .unlocked exists and is true)
	-- intended for making stakes into items
	if G.AP.slot_data.stake_unlock_mode == tonumber(2) then
		if G.P_CENTER_POOLS.Stake[_stake].unlocked then 
		return G.P_CENTER_POOLS.Stake[_stake].unlocked end
		
		return false
	end
	
	-- [Mode 3] individual unlocks
	-- (stakes are unlocked if their entry in deck_usage.stake_unlocks exists and is true)
	-- intended for making each deck's stakes into items
	
	-- (if used, the decks should be removed from the pool and be unlocked when
	-- the player receives a stake for that deck)
	if G.AP.slot_data.stake_unlock_mode == tonumber(3) then
		
		if G.PROFILES[G.SETTINGS.profile].deck_usage and G.PROFILES[G.SETTINGS.profile].deck_usage[_deck_key] and
		G.PROFILES[G.SETTINGS.profile].deck_usage[_deck_key].stake_unlocks then
			return G.PROFILES[G.SETTINGS.profile].deck_usage[_deck_key].stake_unlocks[_stake] or false
		end
		
	end
	
	return false
end

local GUIDEFrun_setup_option = G.UIDEF.run_setup_option
function G.UIDEF.run_setup_option(type)
	if isAPProfileLoaded() then
		
		if not G.SAVED_GAME then
			G.SAVED_GAME = get_compressed(G.SETTINGS.profile..'/'..'save.jkr')
			if G.SAVED_GAME ~= nil then G.SAVED_GAME = STR_UNPACK(G.SAVED_GAME) end
		end

		-- fix AP stake cursor when viewing the continue screen
		if G.SAVED_GAME ~= nil then
			saved_game = G.SAVED_GAME
			G.viewed_stake = saved_game.GAME.stake or 1
			G.viewed_stake_act[2] = saved_game.GAME.stake or 1
			G.viewed_stake_act[1] = 0
		end
	end
	return GUIDEFrun_setup_option(type)
end


local UIDEF_deck_stake_columnRef = G.UIDEF.deck_stake_column
function G.UIDEF.deck_stake_column(_deck_key)
    --hijack to use custom logic in AP
    if isAPProfileLoaded() then
        local deck_usage = G.PROFILES[G.SETTINGS.profile].deck_usage[_deck_key]
		local stake_col = {}
		local valid_option = nil
		local num_stakes = 0
		
		for i = #G.AP.slot_data.included_stakes, 1, -1 do
			if check_stake_unlock(i, _deck_key) == true then
				num_stakes = #G.AP.slot_data.included_stakes
				break
			end
		end
		
		for i = num_stakes, 1, -1 do
			valid_option = false
			local _wins = deck_usage and deck_usage.wins[i] or 0
			if check_stake_unlock(i, _deck_key) == true then valid_option = true end
			
			stake_col[#stake_col + 1] = {n = G.UIT.R, config = {id = i, align = "cm", colour = _wins > 0 and G.C.GREY or G.C.CLEAR, outline = 0, outline_colour = G.C.WHITE, r = 0.1, minh = 2 / 8, minw = valid_option and 0.45 or 0.25, func = 'RUN_SETUP_check_back_stake_highlight'}, nodes = {
				{n = G.UIT.R, config = {align = "cm", minh = valid_option and 1.36 / 8 or 1.04 / 8, minw = valid_option and 0.37 or 0.13, colour = _wins > 0 and get_stake_col(i) or G.C.UI.TRANSPARENT_LIGHT, r = 0.1}, nodes = {}}}}
			if i > 1 then stake_col[#stake_col + 1] = {n = G.UIT.R, config = {align = "cm", minh = 0.8 / 8, minw = 0.04 }, nodes = {} } end
		end
		return {n = G.UIT.ROOT, config = {align = 'cm', colour = G.C.CLEAR}, nodes = stake_col}
    else
        return UIDEF_deck_stake_columnRef(_deck_key)
    end
end

local stake_optionRef = G.UIDEF.stake_option
function G.UIDEF.stake_option(_type)
	--hijack the logic when AP is loaded
	if isAPProfileLoaded() then
		local middle = {n=G.UIT.R, config={align = "cm", minh = 1.7, minw = 7.3}, nodes={
		{n=G.UIT.O, config={id = nil, func = 'RUN_SETUP_check_stake2', object = Moveable()}},}}
		
		local stake_options = {}
		-- add unlocked stakes as options
		for i = 1, #G.AP.slot_data.included_stakes, 1 do
			if check_stake_unlock(i, G.GAME.viewed_back.effect.center.key) == true then
				stake_options[#stake_options+1] = i
			end
		end
	
		-- when everything is locked, force the cursor into the bottom slot
		if #stake_options == 0 then
			G.viewed_stake = 1
			G.viewed_stake_act[1] = 1
			G.viewed_stake_act[2] = G.viewed_stake_act[2]
		else
			for i = 1, #stake_options, 1 do
				if stake_options[i] <= G.viewed_stake_act[2] then
					G.viewed_stake_act[1] = i
				end
			end
			G.viewed_stake = stake_options[G.viewed_stake_act[1]]
			G.viewed_stake_act[2] = stake_options[G.viewed_stake_act[1]]
		end
	  
		return  {n=G.UIT.ROOT, config={align = "tm", colour = G.C.CLEAR, minh = 2.03, minw = 8.3}, nodes={_type == 'Continue' and middle or create_option_cycle({options = stake_options,
		opt_callback = 'change_stake', current_option = G.viewed_stake_act[1], colour = G.C.RED, w = 6, mid = middle})}}
	else
    		return stake_optionRef(_type)
	end
end

-- cursor logic
local GFUNCSchange_stakeRef = G.FUNCS.change_stake
G.FUNCS.change_stake = function(args)
	if isAPProfileLoaded() then
		local valid_stakes = {}
		for i = 1, #G.AP.slot_data.included_stakes, 1 do
			if check_stake_unlock(i, G.GAME.viewed_back.effect.center.key) == true then valid_stakes[#valid_stakes+1] = i end
		end
		
		if args.cycle_config then
			G.viewed_stake_act[1] = args.to_key
			G.viewed_stake_act[2] = valid_stakes[G.viewed_stake_act[1]]
		else
			for k,v in pairs(valid_stakes) do
				if v == args.to_key then
					G.viewed_stake_act[1] = k
					G.viewed_stake_act[2] = valid_stakes[G.viewed_stake_act[1]]
					break
				end
			end
		end
	
		if #valid_stakes == 0 then
			G.viewed_stake = 1
			G.viewed_stake_act[1] = 1
			G.viewed_stake_act[2] = 1
			G.PROFILES[G.SETTINGS.profile].MEMORY.stake = 1
		else
			G.viewed_stake = valid_stakes[G.viewed_stake_act[1]]
			G.PROFILES[G.SETTINGS.profile].MEMORY.stake = G.viewed_stake
			G.viewed_stake_act[2] = valid_stakes[G.viewed_stake_act[1]]
		end
	else
		return GFUNCSchange_stakeRef(args)
	end
end

local game_splash_screenRef = Game.splash_screen
function Game:splash_screen()
-- initiate stake swap (i need stakes to exist to do it)
	if isAPProfileLoaded() then init_AP_stakes() end
	return game_splash_screenRef(self)
end

-- handle stakes (stuff that can be easily handled by patches)
--white highlight on stake selection
local GFUNCSRUN_SETUP_check_back_stake_highlightRef = G.FUNCS.RUN_SETUP_check_back_stake_highlight
G.FUNCS.RUN_SETUP_check_back_stake_highlight= function(e) 
	if isAPProfileLoaded() then
		if G.viewed_stake_act[2] == e.config.id and e.config.outline < 0.1 then 
			e.config.outline = check_stake_unlock(G.viewed_stake_act[2], G.GAME.viewed_back.effect.center.key) == true and 0.8 or 0
		elseif G.viewed_stake_act[2] ~= e.config.id and e.config.outline > 0.1 then
			e.config.outline = 0
		end
	else
		return GFUNCSRUN_SETUP_check_back_stake_highlightRef(e)
	end
end

--deck win stickers (check stake level instead of slot)
local get_deck_win_stickerRef = get_deck_win_sticker
function get_deck_win_sticker(_center)
	if isAPProfileLoaded() then
		if G.PROFILES[G.SETTINGS.profile].deck_usage[_center.key] and G.PROFILES[G.SETTINGS.profile].deck_usage[_center.key].wins then 
			local _w = -1
			for k, v in pairs(G.PROFILES[G.SETTINGS.profile].deck_usage[_center.key].wins) do
				if v > 0 then
					_w = math.max(G.P_CENTER_POOLS.Stake[k].stake_level, _w)
				end
	   		end
	   		if _w > 0 then return G.sticker_map[_w] end
		end
	else
		return get_deck_win_sticker(_center)
	end
end

-- joker win stickers (check stake level instead of slot)
local get_joker_win_stickerRef = get_joker_win_sticker
function get_joker_win_sticker(_center, index)
	if isAPProfileLoaded() then
		if G.PROFILES[G.SETTINGS.profile].joker_usage[_center.key] and G.PROFILES[G.SETTINGS.profile].joker_usage[_center.key].wins then 
			local _w = 0
			for k, v in pairs(G.PROFILES[G.SETTINGS.profile].joker_usage[_center.key].wins) do
				_w = math.max(G.P_CENTER_POOLS.Stake[k].stake_level, _w)
			end
			if index then return _w end
			if _w > 0 then return G.sticker_map[_w] end
		end
		if index then return 0 end
	else
		return get_joker_win_stickerRef(_center, index)
	end
end

-- set deck win (prevent higher stake wins from counting as a win for previous stakes)
local set_deck_winRef = set_deck_win
function set_deck_win()
	if isAPProfileLoaded() then
		if G.GAME.selected_back and G.GAME.selected_back.effect and G.GAME.selected_back.effect.center and G.GAME.selected_back.effect.center.key then
			local deck_key = G.GAME.selected_back.effect.center.key
			if not G.PROFILES[G.SETTINGS.profile].deck_usage[deck_key] then G.PROFILES[G.SETTINGS.profile].deck_usage[deck_key] = {count = 1, order = G.GAME.selected_back.effect.center.order, wins = {}, losses = {}} end
			if G.PROFILES[G.SETTINGS.profile].deck_usage[deck_key] then
				G.PROFILES[G.SETTINGS.profile].deck_usage[deck_key].wins[G.GAME.stake] = (G.PROFILES[G.SETTINGS.profile].deck_usage[deck_key].wins[G.GAME.stake] or 0) + 1
			end
			set_challenge_unlock()
			G:save_settings()
		end
	else
		return set_deck_winRef()
	end
end

-- stakes button
local GUIDEFrun_infoRef = G.UIDEF.run_info
function G.UIDEF.run_info()
	local _run_info = GUIDEFrun_infoRef()
	
	if isAPProfileLoaded() then
		local _stake_slot = G.GAME.stake
		G.GAME.stake = G.P_CENTER_POOLS.Stake[_stake_slot].stake_level
		_run_info = GUIDEFrun_infoRef()
		G.GAME.stake = _stake_slot
	end

	return _run_info
end

-- "also applies" in stakes menu
local GUIDEFcurrent_stakeRef = G.UIDEF.current_stake
function G.UIDEF.current_stake()
	local _current_stake = GUIDEFcurrent_stakeRef()
	
	if isAPProfileLoaded() then
		local _stake_slot = G.GAME.stake
		G.GAME.stake = G.P_CENTER_POOLS.Stake[_stake_slot].stake_level
		_current_stake = GUIDEFcurrent_stakeRef()
		G.GAME.stake = _stake_slot
	end
	
	return _current_stake
end


-- handle shop cards

local card_apply_to_runRef = Card.apply_to_run
function Card:apply_to_run(center)
    if isAPProfileLoaded() then

        local center_table = {
            name = center and center.name or self and self.ability.name,
            extra = center and center.config.extra or self and self.ability.extra
        }

        -- properly handle seed money and money tree vouchers when bonus interest_cap was received already
        if center_table.name == 'Seed Money' then
            center_table.extra = center_table.extra + (G.GAME.interest_cap - 25)
        end

        if center_table.name == 'Money Tree' then
            center_table.extra = center_table.extra + (G.GAME.interest_cap - 50)
        end
    end

    return card_apply_to_runRef(self, center)
end

local get_next_voucher_keyRef = get_next_voucher_key
function get_next_voucher_key(_from_tag)
    local get_next_voucher = get_next_voucher_keyRef(_from_tag)
    -- normally when no voucher is available it would put blank in shop, prevent that (if blank is not unlocked)
    if isAPProfileLoaded() then
        if G.P_LOCKED[get_next_voucher] or get_next_voucher == 'v_rand_ap_item' or get_next_voucher == "UNAVAILABLE" then
            return nil
        end
    end

    return get_next_voucher
end

local create_cardRef = create_card

function create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
    -- to properly generate only unlocked jokers in buffoon packs
    if isAPProfileLoaded() and G.STATE == G.STATES.BUFFOON_PACK and _type == 'Joker' and (G.P_CENTERS) then
        for k, v in pairs(G.P_CENTERS) do
            if string.find(tostring(k), '^j_') then
                v.foo = v.unlocked
                v.unlocked = v.ap_unlocked
            end
        end
    end

    local create_card = create_cardRef(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key,
        key_append)

    if isAPProfileLoaded() and G.STATE == G.STATES.BUFFOON_PACK and _type == 'Joker' and (G.P_CENTERS) then
        for k, v in pairs(G.P_CENTERS) do
            if string.find(tostring(k), '^j_') then
                v.unlocked = v.foo
                v.foo = nil
            end
        end
    end

    return create_card
end

local cardArea_emplaceRef = CardArea.emplace
function CardArea:emplace(card, location, stay_flipped)
    if (isAPProfileLoaded() and card.config.center_key == 'v_rand_ap_item' and G.STATE == G.STATES.SHOP) then
        ap_items_in_shop = ap_items_in_shop + 1
    end

    local cardAreaemplace = nil

    if (self.cards) then
        cardAreaemplace = cardArea_emplaceRef(self, card, location, stay_flipped)
    else
        self:remove_card(card, false)
        card:start_dissolve({G.C.RED}, true, 0)
    end

    if self.cards and ((isAPProfileLoaded() and card.config.center.unlocked == false and
        (G.STATE == G.STATES.SHOP or G.STATE == G.STATES.TAROT_PACK or G.STATE == G.STATES.SPECTRAL_PACK or G.STATE ==
            G.STATES.PLANET_PACK or G.STATE == G.STATES.BUFFOON_PACK or self == G.shop_jokers or self == G.jokers or
            self == G.consumeables or self == G.pack_cards)) or

        (isAPProfileLoaded() and card.config.center_key == 'v_rand_ap_item' and ap_items_in_shop > 1 and G.STATE ==
            G.STATES.SHOP) or (card.config.center_key == "j_joker" and card.config.center.unlocked == true) or
        (card.config.center_key == "c_pluto" and card.config.center.unlocked == true) or
        (card.config.center_key == "c_strength" and card.config.center.unlocked == true) or
        (card.config.center_key == "c_incantation" and card.config.center.unlocked == true)) then

        -- following blocks handle standard cards appearing in packs/shop
        if not next(find_joker("Showman")) and card.config.center.unlocked == true then
            if (card.config.center_key == "j_joker" and card.config.center.unlocked == true) and self == G.pack_cards then
                local found_self = false
                -- if you already have the Joker and don't have showman, delete
                if next(find_joker("Joker")) and not next(find_joker("Showman")) then

                    self:remove_card(card, false)
                    card:start_dissolve({G.C.RED}, true, 0)

                    return cardAreaemplace
                end

                for k, v in pairs(self.cards) do
                    if v.config.center.key == "j_joker" then
                        if v.config.center.ap_unlocked then
                            if not found_self then
                                found_self = true
                            else
                                self:remove_card(card, false)
                                card:start_dissolve({G.C.RED}, true, 0)

                                return cardAreaemplace
                            end

                        else
                            self:remove_card(card, false)
                            card:start_dissolve({G.C.RED}, true, 0)

                            return cardAreaemplace
                        end
                    end
                end

                return cardAreaemplace
            end

            if (card.config.center_key == "c_pluto" and card.config.center.unlocked == true) and
                (G.STATE == G.STATES.PLANET_PACK or G.STATE == G.STATES.SHOP) then
                local found_self = false

                for k, v in pairs(self.cards) do
                    if v.config.center.key == "c_pluto" then

                        if not found_self then
                            found_self = true
                        else
                            self:remove_card(card, false)
                            card:start_dissolve({G.C.RED}, true, 0)

                            return cardAreaemplace
                        end
                    end
                end

                return cardAreaemplace
            end

            if (card.config.center_key == "c_strength" and card.config.center.unlocked == true) and
                (G.STATE == G.STATES.TAROT_PACK or G.STATE == G.STATES.SHOP) then
                local found_self = false

                for k, v in pairs(self.cards) do
                    if v.config.center.key == "c_strength" then

                        if not found_self then
                            found_self = true
                        else
                            self:remove_card(card, false)
                            card:start_dissolve({G.C.RED}, true, 0)

                            return cardAreaemplace
                        end
                    end
                end

                return cardAreaemplace
            end

            if (card.config.center_key == "c_incantation" and card.config.center.unlocked == true) and
                (G.STATE == G.STATES.SPECTRAL_PACK or G.STATE == G.STATES.SHOP) then
                local found_self = false

                for k, v in pairs(self.cards) do
                    if v.config.center.key == "c_incantation" then

                        if not found_self then
                            found_self = true
                        else
                            self:remove_card(card, false)
                            card:start_dissolve({G.C.RED}, true, 0)

                            return cardAreaemplace
                        end
                    end
                end

                return cardAreaemplace
            end

        end

        if card.config.center.unlocked == false or
            (isAPProfileLoaded() and card.config.center_key == 'v_rand_ap_item' and ap_items_in_shop > 1 and G.STATE ==
                G.STATES.SHOP) then
            self:remove_card(card, false)
            card:start_dissolve({G.C.RED}, true, 0)
        end

    end
    if isAPProfileLoaded() and card.config.center.unlocked == true and card.config.center.ap_unlocked == false then
        card:set_debuff(true)
    end

    return cardAreaemplace
end

local card_set_debuffRef = Card.set_debuff

function Card:set_debuff(should_debuff)

    if isAPProfileLoaded() and self.config.center.ap_unlocked == false and should_debuff == false then
        should_debuff = true
    end

    return card_set_debuffRef(self, should_debuff)

end

local can_skip_boosterRef = G.FUNCS.can_skip_booster
G.FUNCS.can_skip_booster = function(e)
    if isAPProfileLoaded() then
        if G.pack_cards and G.pack_cards.cards and
            (G.STATE == G.STATES.PLANET_PACK or G.STATE == G.STATES.STANDARD_PACK or G.STATE == G.STATES.BUFFOON_PACK or
                (G.hand and (G.hand.cards[1] or (G.hand.config.card_limit <= 0)))) then
            e.config.colour = G.C.GREY
            e.config.button = 'skip_booster'
        else
            e.config.colour = G.C.UI.BACKGROUND_INACTIVE
            e.config.button = nil
        end

        return
    end
    return can_skip_boosterRef(e)
end

local card_can_use_consumeableRef = Card.can_use_consumeable
function Card:can_use_consumeable(any_state, skip_check)
    if (isAPProfileLoaded()) then
        if (self.config and self.config.center) then
            if self.config.center.unlocked == true then

                -- to avoid weird bug 
                if self.ability and self.ability.consumeable and self.ability.consumeable.mod_num == nil then
                    self.ability.consumeable.mod_num = -1
                end

                local card_can_use_result = card_can_use_consumeableRef(self, any_state, skip_check)

                if self.ability and self.ability.consumeable and self.ability.consumeable.mod_num == -1 then
                    self.ability.consumeable.mod_num = nil
                end

                return card_can_use_result
            end
        end
        return false
    end

    return card_can_use_consumeableRef(self, any_state, skip_check)
end

-- AP Items in shop

function tableContains(table, value)
    for i = 1, #table do
        if (table[i] == value) then
            return true
        end
    end
    return false
end

local voucher_name = 'Archipelago Item'
local voucher_slug = 'ap_item'
local min_cost = 1
local max_cost = 10

G.FUNCS.initialize_shop_items = function()
    min_cost = G.AP.slot_data.minimum_price
    max_cost = G.AP.slot_data.maximum_price
end

SMODS.Atlas {
    key = "ap_item_voucher",
    path = "v_ap_item.png",
    px = 71,
    py = 98
}

SMODS.Atlas {
    key = "ap_logo",
    path = "ap_logo.png",
    px = 66,
    py = 66
}

SMODS.Voucher {
    key = voucher_slug,
    loc_txt = {
        name = voucher_name,
        text = {'Unlocks an AP Item ', 'when redeemed'}
    },
    atlas = 'ap_item_voucher',
    cost = 0,
    unlocked = true,
    discovered = true,
    requires = {'fuck!! shit!!!! (put here anything so it doesnt spawn naturally)'}
}

G.FUNCS.resolve_location_id_to_name = function(id)
    if not G.AP.location_id_to_item_name[id] then
        G.APClient:LocationScouts({id})
    end
end

function get_shop_location()
    if G.AP.slot_data["stake" .. tostring(G.P_CENTER_POOLS.Stake[G.GAME.stake].stake_level) .. "_shop_locations"] then
        for i, v in ipairs(G.AP.slot_data["stake" .. tostring(G.P_CENTER_POOLS.Stake[G.GAME.stake].stake_level) .. "_shop_locations"]) do
            if (tableContains(G.APClient.missing_locations, v)) then
                G.FUNCS.resolve_location_id_to_name(v)
                return v
            end
        end
    end
    return nil
end

local select_blindRef = G.FUNCS.select_blind

G.FUNCS.select_blind = function(e)
    -- scout upcoming locations semi regularly
    get_shop_location()
    local deck_name = G.GAME.selected_back.name

    if (G.GAME.round_resets.ante >= 1 and G.GAME.round_resets.ante <= 8) then
        for k, v in pairs(deck_list) do
            if deck_name == v then
                G.APClient:LocationScouts({G.AP.id_offset + (64 * k) + (G.GAME.round_resets.ante - 1) * 8 +
                    (G.P_CENTER_POOLS.Stake[G.GAME.stake].stake_level - 1)})
                break -- break the loop once the correct deck is found
            end
        end
    end

    return select_blindRef(e)
end

local redeemref = Card.redeem

function Card:redeem()
    -- backup current round voucher in case AP Item Voucher was redeemed
    local current_round_voucher
    if (self.config.center_key == 'v_rand_ap_item') then
        current_round_voucher = G.GAME.current_round.voucher
    end
    redeemref(self)
    if self.config.center_key == 'v_rand_ap_item' then

        local location = get_shop_location()
        if location then
            sendLocationCleared(location)
        end

        G.GAME.current_round.voucher = current_round_voucher
    end
end

local game_update_shopRef = Game.update_shop

function Game:update_shop(dt)

    if isAPProfileLoaded() and not G.STATE_COMPLETE then
        ap_items_in_shop = 0
        local game_update_shop = game_update_shopRef(self, dt)
        -- first check if there are still shop locations to get
        local current_ap_shopitem = get_shop_location()
        if (current_ap_shopitem ~= nil) then
            -- give new random cost each time 
            G.P_CENTERS['v_rand_ap_item'].cost = math.random(min_cost, max_cost)

            G.E_MANAGER:add_event(Event({

                trigger = 'after',
                delay = 0.3,
                blockable = false,
                func = function()
                    local text = 'AP Item'

                    if G.AP.location_id_to_item_name[current_ap_shopitem] and
                        G.AP.location_id_to_item_name[current_ap_shopitem].item_name then
                        text = G.AP.location_id_to_item_name[current_ap_shopitem].player_name .. '\'s ' ..
                                   G.AP.location_id_to_item_name[current_ap_shopitem].item_name
                    end

                    local lines = split_text_to_lines(text)
                    G.localization.descriptions.Voucher['v_rand_ap_item'].text_parsed = {}
                    for k, v in ipairs(lines) do
                        G.localization.descriptions.Voucher['v_rand_ap_item'].text_parsed[k] = loc_parse_string(v)
                    end

                    local voucher_key = 'v_rand_ap_item'
                    G.shop_vouchers.config.card_limit = G.shop_vouchers.config.card_limit + 1
                    local card = Card(G.shop_vouchers.T.x + G.shop_vouchers.T.w / 2, G.shop_vouchers.T.y, G.CARD_W,
                        G.CARD_H, G.P_CARDS.empty, G.P_CENTERS[voucher_key], {
                            bypass_discovery_center = true,
                            bypass_discovery_ui = true
                        })
                    create_shop_card_ui(card, 'Voucher', G.shop_vouchers)
                    card:start_materialize()
                    G.shop_vouchers:emplace(card)

                    return true
                end
            }))
        end

        return game_update_shop
    end
    return game_update_shopRef(self, dt)
end

-- handle profile deletion
G.FUNCS.can_delete_AP_profile = function(e)
    G.AP.CHECK_PROFILE_DATA = G.AP.CHECK_PROFILE_DATA or NFS.getInfo(G.AP.profile_Id .. '/' .. 'profile.jkr')
    if (not G.AP.CHECK_PROFILE_DATA) or e.config.disable_button or
        (G.APClient and G.APClient:get_state() == AP.State.SOCKET_CONNECTING) then
        G.AP.CHECK_PROFILE_DATA = false
        e.config.colour = G.C.UI.BACKGROUND_INACTIVE
        e.config.button = nil
    else
        e.config.colour = G.C.RED
        e.config.button = 'delete_AP_profile'
    end
end

G.FUNCS.delete_AP_profile = function(e)
    if ap_profile_delete then
        G.FUNCS.APDisconnect()
        ap_profile_delete = false
        G.E_MANAGER:add_event(Event({
            trigger = 'after',
            delay = 0.3,
            func = (function()
                G.FUNCS.exit_overlay_menu()
                return true
            end)
        }))
    end
    G.FUNCS.delete_profile(e)
    ap_profile_delete = true
    G.AP.CHECK_PROFILE_DATA = nil

end

local exit_overlay_menuRef = G.FUNCS.exit_overlay_menu
G.FUNCS.exit_overlay_menu = function(e)

    if not isAPProfileLoaded() then
        G.APClient = nil
        collectgarbage("collect")
    end
    return exit_overlay_menuRef(e)
end

-- When Load Profile Button is clicked
local load_profile_funcRef = G.FUNCS.load_profile

G.FUNCS.load_profile = function(delete_prof_data)
    if isAPProfileLoaded() and not isAPProfileSelected() and G.APClient ~= nil then
        G.FUNCS.APDisconnect()
        G.AP.GameObjectInit = false
    end
    ap_profile_delete = false
    return load_profile_funcRef(delete_prof_data)
end

-- other stuff 

-- circumvent Jokers being unlocked normally:

local unlock_cardRef = unlock_card
function unlock_card(card)
    -- only intervene if 1. APProfile is loaded and 2. The receiving item is a AP Item 
    if isAPProfileLoaded() and
        (card.set == 'Back' or card.set == 'Joker' or card.set == "Voucher" or card.set == "Booster" or card.set ==
            "Spectral" or card.set == "Planet" or card.set == "Tarot") then
        return
    end

    return unlock_cardRef(card)
end

local discover_cardRef = discover_card
function discover_card(card)
    if isAPProfileLoaded() and card.unlocked == false and
        (card.set == 'Back' or card.set == 'Joker' or card.set == "Voucher" or card.set == "Booster" or card.set ==
            "Spectral" or card.set == "Planet" or card.set == "Tarot") then
        return
    end
    return discover_cardRef(card)
end

local create_unlock_overlayRef = create_unlock_overlay
function create_unlock_overlay(key)
    if isAPProfileLoaded() then
        return
    end
    return create_unlock_overlayRef(key)
end

function get_unlocked_jokers()
    local count = 0
    if (G.P_CENTERS) then
        for k, v in pairs(G.P_CENTERS) do
            if string.find(tostring(k), '^j_') and v.ap_unlocked == true then
                count = count + 1
            end
        end
    end
    return count
end

-- Here you can unlock checks

local check_for_unlockRef = check_for_unlock
function check_for_unlock(args)
    local check_for_unlock = check_for_unlockRef(args)
    if isAPProfileLoaded() then
        if args.type == 'ante_up' and args.ante and args.ante > 1 and args.ante < 10 then
            -- when an ante is beaten
            local deck_name = G.GAME.selected_back.name

            for k, v in pairs(deck_list) do
                if deck_name == v then
                    sendLocationCleared(G.AP.id_offset + (64 * k) + (args.ante - 2) * 8 + (G.P_CENTER_POOLS.Stake[G.GAME.stake].stake_level - 1))
                    break -- break the loop once the correct deck is found
                end
            end

        end

        -- also need to check for goal completions! (only check during run so accidental loading of a profile doesn't release/collect)
        if G.AP.goal then
            if G.STAGE == G.STAGES.RUN then
                -- beat # of decks goal
                if G.AP.goal == 0 then

                    -- get all individual deck wins 
                    local deck_wins = 0
                    for k, v in pairs(G.P_CENTERS) do
                        if string.find(tostring(k), '^b_') then
                            if G.PROFILES[G.SETTINGS.profile].deck_usage[k] and
                                G.PROFILES[G.SETTINGS.profile].deck_usage[k].wins and
                                #G.PROFILES[G.SETTINGS.profile].deck_usage[k].wins > 0 then
                                deck_wins = deck_wins + 1
                            end
                        end
                    end

                    if deck_wins >= G.AP.slot_data.decks_win_goal then
                        sendGoalReached()
                    end

                    -- unlock # of jokers (must be in run to avoid cringe bugs when loading in)
                elseif G.AP.goal == 1 then
                    if tonumber(get_unlocked_jokers() or 0) >= tonumber(G.AP.slot_data.jokers_unlock_goal) then
                        sendGoalReached()
                    end

                    -- beat ante
                elseif G.AP.goal == 2 then
                    if args.type == 'ante_up' and args.ante >= G.AP.slot_data.ante_win_goal then
                        sendGoalReached()
                    end

                end
            end
        else
            sendDebugMessage("No goal available, this is not good")
        end

    end

    return check_for_unlock
end

function sendGoalReached()
    if G.APClient ~= nil and G.APClient:get_state() == AP.State.SLOT_CONNECTED then
        sendDebugMessage("Goal Reached. Sending Goal Reached to Server")
        G.APClient:StatusUpdate(30)
    end
end

local create_UIBox_notify_alertRef = create_UIBox_notify_alert
function create_UIBox_notify_alert(_achievement, _type)
    if isAPProfileLoaded() and
        (_type == "location" or _type == "Booster" or _type == "Tarot" or _type == "Planet" or _type == "Spectral"
		or (_type == "Joker" and G.P_CENTERS[_achievement].soul_pos)) or _type == "Stake" or _type == "BackStake" then

        local _c, _atlas = G.P_CENTERS[_achievement],
            _type == "Tarot" and G.ASSET_ATLAS["Tarot"] or _type == "Planet" and G.ASSET_ATLAS["Tarot"] or _type ==
                "Spectral" and G.ASSET_ATLAS["Tarot"] or _type == "Booster" and G.ASSET_ATLAS["Booster"] or _type ==
                "location" and G.ASSET_ATLAS["rand_ap_logo"] or _type == 'Stake' and G.ASSET_ATLAS["chips"] or _type == 
		'BackStake' and G.ASSET_ATLAS["centers"] or G.ASSET_ATLAS["icons"]

	--stake-specific _c
	if _type == 'Stake' then
		_c = {pos = {x = 0, y = 0}}
		for i = 1, 8, 1 do
			if G.P_CENTER_POOLS.Stake[i].key == _achievement then
				_c.pos = G.P_CENTER_POOLS.Stake[i].pos
				_c.name = G.P_CENTER_POOLS.Stake[i].name
				break
			end
		end
	end
	
	if _type == 'BackStake' then
		_c = {pos = {x = 0, y = 0}, soul_pos = {x = 0, y = 0}, name = ""}
		for i = 1, 8, 1 do
			if string.find(_achievement, G.P_CENTER_POOLS.Stake[i].key) then
				_c.soul_pos = G.P_CENTER_POOLS.Stake[i].sticker_pos
				_c.name = G.P_CENTER_POOLS.Stake[i].name.." ("
				break
			end
		end
		
		for k, v in pairs(G.P_CENTER_POOLS.Back) do
			if string.find(_achievement, G.P_CENTER_POOLS.Back[k].key) then
				_c.pos = G.P_CENTER_POOLS.Back[k].pos
				_c.name = _c.name..G.P_CENTER_POOLS.Back[k].name..")"
				break
			end
		end
	end
	
        if not _c then
            if _type == "location" then
                _c = {
                    pos = {
                        x = 0,
                        y = 0
                    }
                }
            else -- moved to handle the trophy here because we need to set the x.y manually here for other icons anyway
                _c = {
                    pos = {
                        x = 3,
                        y = 0
                    }
                }
            end -- there's probably a better way, but idk
        end

        local t_s = Sprite(0, 0, 1.5 * (_atlas.px / _atlas.py), 1.5, _atlas, _c.pos)
        t_s.states.drag.can = false
        t_s.states.hover.can = false
        t_s.states.collide.can = false

	-- gold stake shader
	if _type == 'Stake' then
		if _achievement == "stake_gold" then
			t_s.draw = function(_sprite)
				_sprite.ARGS.send_to_shader = _sprite.ARGS.send_to_shader or {}
				_sprite.ARGS.send_to_shader[1] = math.min(_sprite.VT.r*3, 1) + G.TIMERS.REAL/(18) + (_sprite.juice and _sprite.juice.r*20 or 0) + 1
				_sprite.ARGS.send_to_shader[2] = G.TIMERS.REAL

				Sprite.draw_shader(_sprite, 'dissolve')
				Sprite.draw_shader(_sprite, 'voucher', nil, _sprite.ARGS.send_to_shader)
			end
		end
	end
	
	-- second layer for the soul, the hologramm and the legendaries
	if _c and _c.soul_pos then
		local _soul_atlas = _achievement == 'c_soul' and G.ASSET_ATLAS["centers"] or 
			_type == 'BackStake' and G.ASSET_ATLAS["stickers"] or G.ASSET_ATLAS["Joker"]
		local _soul_pos = _achievement == 'c_soul' and {x = 0, y = 1} or _c.soul_pos
		local _soul_t_s = Sprite(t_s.T.x,t_s.T.y,1.5*(_soul_atlas.px/_soul_atlas.py),1.5,_soul_atlas, _soul_pos)
		_soul_t_s.states.drag.can = false
		_soul_t_s.states.hover.can = false
		_soul_t_s.states.collide.can = false
		
		t_s.children.floating_sprite = _soul_t_s
		t_s.children.floating_sprite.role.draw_major = t_s
		_soul_t_s.T = t_s.T
		_soul_t_s.VT = t_s.VT
	end

        local subtext = "Location cleared"
        local name = "Archipelago"

        -- this might be nil if server communication is too slow -> will default to "location cleared"
        if _type == "location" and G.AP.location_id_to_item_name[_achievement] then
            subtext = G.AP.location_id_to_item_name[_achievement].player_name .. '\'s ' ..
                          G.AP.location_id_to_item_name[_achievement].item_name

        end

        if _type ~= "location" then
            if _achievement and _c then
                subtext = _c.name
            else
                subtext = _type
            end
            name = "Unlocked"
        end

        return {
            n = G.UIT.ROOT,
            config = {
                align = 'cl',
                r = 0.1,
                padding = 0.06,
                colour = G.C.UI.TRANSPARENT_DARK
            },
            nodes = {{
                n = G.UIT.R,
                config = {
                    align = "cl",
                    padding = 0.2,
                    minw = 20,
                    r = 0.1,
                    colour = G.C.BLACK,
                    outline = 1.5,
                    outline_colour = G.C.GREY
                },
                nodes = {{
                    n = G.UIT.R,
                    config = {
                        align = "cm",
                        r = 0.1
                    },
                    nodes = {{
                        n = G.UIT.R,
                        config = {
                            align = "cm",
                            r = 0.1
                        },
                        nodes = {{
                            n = G.UIT.O,
                            config = {
                                object = t_s
                            }
                        }}
                    }, {
                        n = G.UIT.R,
                        config = {
                            align = "cm",
                            padding = 0.04
                        },
                        nodes = {{
                            n = G.UIT.R,
                            config = {
                                align = "cm",
                                maxw = 3.4,
                                padding = 0.1
                            },
                            nodes = {{
                                n = G.UIT.T,
                                config = {
                                    text = name,
                                    scale = 0.4,
                                    colour = G.C.UI.TEXT_LIGHT,
                                    shadow = true
                                }
                            }}
                        }, {
                            n = G.UIT.R,
                            config = {
                                align = "cm",
                                maxw = 3.4
                            },
                            nodes = {{
                                n = G.UIT.T,
                                config = {
                                    text = subtext,
                                    scale = 0.7,
                                    colour = G.C.FILTER,
                                    shadow = true
                                }
                            }}
                        }}
                    }}
                }}
            }}
        }

    end

    return create_UIBox_notify_alertRef(_achievement, _type)
end

function sendLocationCleared(id)
    if G.APClient ~= nil and G.APClient:get_state() == AP.State.SLOT_CONNECTED then

        if (tableContains(G.APClient.missing_locations, id)) then
            G.FUNCS.resolve_location_id_to_name(id)
            notify_alert(id, "location")
        end
        G.APClient:LocationChecks({id})
    end
end

-- gets called after connection has been established

G.FUNCS.set_up_APProfile = function()

    sendDebugMessage("set_up_APProfile called")

    G.PROFILES[G.AP.profile_Id]["received_indeces"] = {}
    G.PROFILES[G.AP.profile_Id]["jokers"] = {}
    G.PROFILES[G.AP.profile_Id]["backs"] = {}
    G.PROFILES[G.AP.profile_Id]["vouchers"] = {}
    G.PROFILES[G.AP.profile_Id]["packs"] = {}
    G.PROFILES[G.AP.profile_Id]["consumables"] = {}

    G.PROFILES[G.AP.profile_Id]["bonusdiscards"] = 0
    G.PROFILES[G.AP.profile_Id]["bonusstartingmoney"] = 0
    G.PROFILES[G.AP.profile_Id]["bonushands"] = 0
    G.PROFILES[G.AP.profile_Id]["maxinterest"] = 0
    G.PROFILES[G.AP.profile_Id]["bonusjoker"] = 0
    G.PROFILES[G.AP.profile_Id]["bonusconsumable"] = 0
end

-- prevent achievements from being unlocked
local unlock_achievementRef = unlock_achievement
function unlock_achievement(achievement_name)
    if isAPProfileLoaded() then
        return
    end
    return unlock_achievementRef(achievement_name)
end

-- debug

function copy_uncompressed(_file)
    local file_data = NFS.getInfo(_file)
    if file_data ~= nil then
        local file_string = NFS.read(_file)
        if file_string ~= '' then
            local success = nil
            success, file_string = pcall(love.data.decompress, 'string', 'deflate', file_string)
            NFS.write(_file .. ".txt", file_string)
        end
    end
end

-- fix turning '0' into 'o'
local zeroWasInput = false

local text_input_keyRef = G.FUNCS.text_input_key
function G.FUNCS.text_input_key(args)
    if args.key == '0' then
        zeroWasInput = true
    end

    local text_input_key = text_input_keyRef(args)
    zeroWasInput = false

    return text_input_key

end

local modify_text_inputRef = MODIFY_TEXT_INPUT
function MODIFY_TEXT_INPUT(args)

    if zeroWasInput then
        args.letter = '0'
    end

    local modify_text_input = modify_text_inputRef(args)

    return modify_text_input

end

----------------------------------------------
------------MOD CODE END----------------------
