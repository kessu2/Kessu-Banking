local ESX
local inMenu = false
local RESOURCE = GetCurrentResourceName()
local wasNear = false

Locale = {}
local okFi, fi = pcall(require, 'locales.fi')
local okEn, en = pcall(require, 'locales.en')
Locale.fi = (okFi and fi) or {}
Locale.en = (okEn and en) or {}

local function getLocale()
	local lang = Config and Config.Locale or 'fi'
	return Locale[lang] or Locale.fi
end

local function getByPath(t, key)
	for part in string.gmatch(key, '[^.]+') do
		t = t and t[part]
	end
	return t
end

function L(key, ...)
	local t = getLocale()
	local s = getByPath(t, key) or key
	if select('#', ...) > 0 then
		return string.format(s, ...)
	end
	return s
end

function LocaleFlatten(lang)
	lang = lang or (Config and Config.Locale) or 'fi'
	local src = Locale[lang] or Locale.fi
	local out = {}
	local function walk(t, prefix)
		for k, v in pairs(t) do
			local key = prefix and (prefix .. '.' .. k) or k
			if type(v) == 'table' then
				walk(v, key)
			else
				out[key] = v
			end
		end
	end
	walk(src)
	return out
end

local function notify(opts)
	if type(opts) == 'string' then
		opts = { description = opts }
	end
	lib.notify(opts or {})
end

local function sendBalanceToNUI(data)
	SendNUIMessage({
		type         = 'balanceHUD',
		resourceName = RESOURCE,
		balance      = data and data.balance or 0,
		player       = (data and data.playerName) or GetPlayerName(PlayerId()) or L('default.playername'),
		transactions = (data and data.transactions) or {},
		avatar       = (data and data.avatar) or '',
	})
end

CreateThread(function()
	ESX = exports['es_extended']:getSharedObject()
	if not ESX then
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
	end
end)

local function openBank()
	if inMenu then return end
	lib.requestAnimDict('amb@prop_human_atm@male@enter', 1000)
	local success = lib.progressCircle({
		label     = L('progress.opening'),
		duration  = 3000,
		position  = 'bottom',
		canCancel = true,
		disable   = {
			move   = true,
			car    = true,
			sprint = true,
			combat = true,
		},
		anim = {
			dict = 'amb@prop_human_atm@male@enter',
			clip = 'enter',
			flag = 49,
		},
	})
	if not success then
		ClearPedTasks(cache.ped or PlayerPedId())
		return
	end
	inMenu = true
	SetNuiFocus(true, true)
	local lang = Config.Locale or 'fi'
	SendNUIMessage({
		type         = 'openGeneral',
		resourceName = RESOURCE,
		locale       = LocaleFlatten(lang),
	})
	local data = lib.callback.await('bank:getBalance', false)
	sendBalanceToNUI(data or {})
end

local function closeBank()
	inMenu = false
	wasNear = false
	SetNuiFocus(false, false)
	SendNUIMessage({ type = 'closeAll' })
	lib.hideTextUI()
end

local function dist3(x1, y1, z1, x2, y2, z2)
	x1, y1, z1 = tonumber(x1) or 0, tonumber(y1) or 0, tonumber(z1) or 0
	x2, y2, z2 = tonumber(x2) or 0, tonumber(y2) or 0, tonumber(z2) or 0
	return GetDistanceBetweenCoords(x1, y1, z1, x2, y2, z2, true)
end

local function coordsFrom(c)
	if not c then return 0, 0, 0 end
	return tonumber(c.x or c[1]) or 0, tonumber(c.y or c[2]) or 0, tonumber(c.z or c[3]) or 0
end

local function playerCoords()
	local ped = cache.ped or PlayerPedId()
	local a, b, c = GetEntityCoords(ped)
	if b == nil and c == nil and a then
		local v = a
		local x = v.x or v[1]
		local y = v.y or v[2]
		local z = v.z or v[3]
		if x ~= nil and y ~= nil and z ~= nil then
			return tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0
		end
	end
	return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

local function nearBank()
	local x, y, z = playerCoords()
	local dist = 1.5
	for i = 1, #Config.Banks do
		local cx, cy, cz = coordsFrom(Config.Banks[i])
		if dist3(cx, cy, cz, x, y, z) <= dist then return true end
	end
	return false
end

local atmPropHashes
local function isATMProp()
	local props = Config.ATMProps
	if not props or #props == 0 then return false end
	if not atmPropHashes then
		atmPropHashes = {}
		for _, name in ipairs(props) do
			atmPropHashes[#atmPropHashes + 1] = GetHashKey(name)
		end
	end
	local x, y, z = playerCoords()
	local range = 1.5
	for _, hash in ipairs(atmPropHashes) do
		local obj = GetClosestObjectOfType(x, y, z, range, hash, false, false, false)
		if obj and obj ~= 0 then
			return true
		end
	end
	return false
end

local function nearATM()
	return isATMProp()
end

CreateThread(function()
		Wait(2000)
		while true do
			local sleep = 1000
			local hasBanks = Config and Config.Banks and #Config.Banks > 0
			local hasATMs = Config and Config.ATMProps and #Config.ATMProps > 0
			if not Config or (not hasBanks and not hasATMs) then
				Wait(1000)
			else
				if inMenu then
					sleep = 200
					if IsControlJustPressed(0, 322) then
						closeBank()
					end
				else
					local nearBankArea = nearBank()
					local nearATMArea  = nearATM()
					local near         = nearBankArea or nearATMArea
					local useTextUI    = (nearBankArea and not Config.TargetBank) or (nearATMArea and not Config.Target)
					if near then
						sleep = useTextUI and 0 or 150
						if useTextUI then
							local text = nearATMArea and L('textui.openatm') or L('textui.openbank')
							lib.showTextUI(text, {
								position = 'left-center',
								icon     = 'credit-card',
							})
							wasNear = true
							if IsControlJustPressed(0, 38) then
								lib.hideTextUI()
								wasNear = false
								openBank()
							end
						else
							if wasNear then
								lib.hideTextUI()
								wasNear = false
							end
						end
					else
						if wasNear then
							lib.hideTextUI()
							wasNear = false
						end
					end
					if IsControlJustPressed(0, 322) then
						closeBank()
					end
				end
			end
			Wait(sleep)
		end
	end)

if Config.Target and Config.ATMProps and #Config.ATMProps > 0 then
	CreateThread(function()
		if GetResourceState('ox_target') ~= 'started' then
			return
		end
		exports.ox_target:addModel(Config.ATMProps, {
			{
				name  = 'bank_open',
				icon  = 'fa-solid fa-credit-card',
				label = L('target.openbank'),
				event = RESOURCE .. ':openBank',
			},
		})
	end)
end

if Config.TargetBank and Config.Banks and #Config.Banks > 0 then
	CreateThread(function()
		if GetResourceState('ox_target') ~= 'started' then
			return
		end
		local radius = 1.5
		for i = 1, #Config.Banks do
			local c = Config.Banks[i]
			local coords = vector3(c.x, c.y, c.z)
			exports.ox_target:addSphereZone({
				coords = coords,
				radius = radius,
				name   = RESOURCE .. ':bank_' .. i,
				options = {
					{
						name  = 'bank_open',
						icon  = 'fa-solid fa-landmark',
						label = L('target.openbank'),
						event = RESOURCE .. ':openBank',
					},
				},
			})
		end
	end)
end

RegisterNetEvent(RESOURCE .. ':openBank', openBank)
RegisterNetEvent(RESOURCE .. ':notify', notify)

if Config.ShowBlips then
	CreateThread(function()
		for i = 1, #Config.Banks do
			local c    = Config.Banks[i]
			local blip = AddBlipForCoord(c.x, c.y, c.z)
			SetBlipSprite(blip, Config.BankBlipSprite or 108)
			SetBlipColour(blip, Config.BankBlipColor or 2)
			SetBlipScale(blip, Config.BankBlipScale or 1.0)
			SetBlipAsShortRange(blip, true)
			BeginTextCommandSetBlipName('STRING')
			AddTextComponentString(L('blip.bank'))
			EndTextCommandSetBlipName(blip)
		end
	end)
end

RegisterNUICallback('deposit', function(data, cb)
	local amount = tonumber(data.amount)
	if not amount or amount < 1 then
		cb({})
		return
	end
	local res = lib.callback.await('bank:deposit', false, amount)
	if res and res.success then
		notify({
			title       = L('notify.deposittitle'),
			description = L('notify.depositsuccess', amount),
			type        = 'success',
		})
		sendBalanceToNUI(res)
	else
		notify({
			title       = L('notify.banktitle'),
			description = res and res.message or L('notify.errorgeneric'),
			type        = 'error',
		})
	end
	cb(res or {})
end)

RegisterNUICallback('withdrawl', function(data, cb)
	local amount = tonumber(data.amountw)
	if not amount or amount < 1 then
		cb({})
		return
	end
	local res = lib.callback.await('bank:withdraw', false, amount)
	if res and res.success then
		notify({
			title       = L('notify.withdrawtitle'),
			description = L('notify.withdrawsuccess', amount),
			type        = 'success',
		})
		sendBalanceToNUI(res)
	else
		notify({
			title       = L('notify.banktitle'),
			description = res and res.message or L('notify.errorgeneric'),
			type        = 'error',
		})
	end
	cb(res or {})
end)

RegisterNUICallback('balance', function(_, cb)
	local data = lib.callback.await('bank:getBalance', false)
	sendBalanceToNUI(data)
	cb({})
end)

RegisterNUICallback('transfer', function(data, cb)
	local to     = tonumber(data.to)
	local amount = tonumber(data.amountt)
	if not to or not amount or amount < 1 then
		cb({})
		return
	end
	local res = lib.callback.await('bank:transfer', false, to, amount)
	if res and res.success then
		notify({
			title       = L('notify.transfertitle'),
			description = L('notify.transfersuccess', amount, to),
			type        = 'success',
		})
		sendBalanceToNUI(res)
	else
		notify({
			title       = L('notify.transfertitle'),
			description = res and res.message or L('notify.errorgeneric'),
			type        = 'error',
		})
	end
	cb(res or {})
end)

RegisterNUICallback('NUIFocusOff', function(_, cb)
	closeBank()
	cb({})
end)

RegisterNUICallback('setBlurState', function(data, cb)
	cb({})
	if not Config.Blur then
		return
	end
	pcall(function()
		if data.enabled then
			TriggerScreenblurFadeIn(500)
		else
			TriggerScreenblurFadeOut(500)
		end
	end)
end)
