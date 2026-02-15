Config = {}

Config.Locale = 'fi' -- fi & en

Config.Blur = false
Config.Target = false -- target for atm, true / false
Config.TargetBank = false -- target for banks, true / false

-- https://wiki.rage.mp/wiki/Blips
Config.BankBlipSprite = 108
Config.BankBlipScale = 1.0
Config.BankBlipColor = 2
Config.ShowBlips = true

Config.Banks = {
	vec3(150.266, -1040.203, 29.374),
	vec3(-1212.980, -330.841, 37.787),
	vec3(-2962.582, 482.627, 15.703),
	vec3(-112.202, 6469.295, 31.626),
	vec3(314.187, -278.621, 54.170),
	vec3(-351.534, -49.529, 49.042),
	vec3(241.727, 220.706, 106.286),
	vec3(1175.064, 2706.644, 38.094),
	vec3(4477.6, -4464.84, 4.24),
}

Config.ATMProps = {
	'prop_atm_01',
	'prop_atm_02',
	'prop_atm_03',
	'prop_fleeca_atm',
}
