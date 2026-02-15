local RESOURCE = GetCurrentResourceName()
local LOG = {}
local MAX_LOG = 50

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

local function logAdd(identifier, ttype, amount, extra)
	if not LOG[identifier] then LOG[identifier] = {} end
	table.insert(LOG[identifier], 1, {
		type = ttype,
		amount = amount,
		time = os.date('%d.%m.%Y %H:%M'),
		extra = extra,
	})
	while #LOG[identifier] > MAX_LOG do table.remove(LOG[identifier]) end
end

local function logGet(identifier, limit)
	limit = limit or 20
	if not LOG[identifier] then return {} end
	local out = {}
	for i = 1, math.min(limit, #LOG[identifier]) do out[i] = LOG[identifier][i] end
	return out
end

local ESX = exports['es_extended']:getSharedObject()

local function avatar(source)
	local a
	pcall(function()
		a = (exports['Badger_Discord_API'] and exports['Badger_Discord_API']:GetDiscordAvatar(source))
	end)
	return a
end

local function balancePayload(source, xPlayer)
	if not xPlayer then return nil end
	return {
		success = true,
		balance = xPlayer.getAccount('bank').money,
		transactions = logGet(xPlayer.identifier, 20),
		avatar = avatar(source),
		playerName = xPlayer.getName(),
	}
end

lib.callback.register('bank:getBalance', function(source)
	local xPlayer = ESX.GetPlayerFromId(source)
	return balancePayload(source, xPlayer)
end)

lib.callback.register('bank:deposit', function(source, amount)
	local xPlayer = ESX.GetPlayerFromId(source)
	if not xPlayer then return { success = false, message = L('error.playernotfound') } end
	amount = tonumber(amount)
	if not amount or amount <= 0 then return { success = false, message = L('error.invalidamount') } end
	if amount > xPlayer.getMoney() then return { success = false, message = L('error.notenoughcash') } end
	logAdd(xPlayer.identifier, 'deposit', amount, nil)
	TriggerEvent('esx:pankkiTALLETUS', xPlayer.getName(), amount)
	xPlayer.removeMoney(amount)
	xPlayer.addAccountMoney('bank', amount)
	return balancePayload(source, xPlayer)
end)

lib.callback.register('bank:withdraw', function(source, amount)
	local xPlayer = ESX.GetPlayerFromId(source)
	if not xPlayer then return { success = false, message = L('error.playernotfound') } end
	amount = tonumber(amount)
	local balance = xPlayer.getAccount('bank').money
	if not amount or amount <= 0 then return { success = false, message = L('error.invalidamount') } end
	if amount > balance then return { success = false, message = L('error.notenoughbalance') } end
	logAdd(xPlayer.identifier, 'withdraw', amount, nil)
	TriggerEvent('esx:pankkiOTTO', xPlayer.getName(), amount)
	xPlayer.removeAccountMoney('bank', amount)
	xPlayer.addMoney(amount)
	return balancePayload(source, xPlayer)
end)

lib.callback.register('bank:transfer', function(source, targetId, amount)
	local xPlayer = ESX.GetPlayerFromId(source)
	if not xPlayer then return { success = false, message = L('error.playernotfound') } end
	local zPlayer = ESX.GetPlayerFromId(tonumber(targetId))
	if not zPlayer then return { success = false, message = L('error.targetnotfound') } end
	if source == zPlayer.source then return { success = false, message = L('error.cannottransferself') } end
	amount = tonumber(amount)
	local balance = xPlayer.getAccount('bank').money
	if not amount or amount <= 0 then return { success = false, message = L('error.invalidamount') } end
	if balance < amount then return { success = false, message = L('error.notenoughbalance') } end
	logAdd(xPlayer.identifier, 'transfer_sent', amount, 'ID: ' .. targetId)
	logAdd(zPlayer.identifier, 'transfer_received', amount, 'ID: ' .. source)
	xPlayer.removeAccountMoney('bank', amount)
	zPlayer.addAccountMoney('bank', amount)
	TriggerClientEvent(RESOURCE .. ':notify', zPlayer.source, {
		title       = L('notify.transfertitle'),
		description = L('notify.transferreceived', amount, source),
		type        = 'success',
	})
	return balancePayload(source, xPlayer)
end)
