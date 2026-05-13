#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <nvault>

#define PLUGIN  "Weapons Skins"
#define VERSION "2.1-fixed"
#define AUTHOR  "Hasan Mdaraty"

#define MAX_WEAPONS 29
#define MAX_SKINS   96

#define MAX_SKIN_NAME 64
#define MAX_MODEL     128
#define MAX_DESC      128
#define MAX_FLAGS     32
#define MAX_PREFIX    64

#define SKIN_MAGIC 20260512
#define NO_SKIN -1

#define TASK_APPLY_SKIN 5000
#define TASK_WARMUP_FIX 6000

new const g_WeaponSection[MAX_WEAPONS][] =
{
	"p228", "scout", "hegrenade", "xm1014", "c4",
	"mac10", "aug", "smokegrenade", "elite", "fiveseven",
	"ump45", "sg550", "galil", "famas", "usp",
	"glock18", "awp", "mp5navy", "m249", "m3",
	"m4a1", "tmp", "g3sg1", "flashbang", "deagle",
	"sg552", "ak47", "knife", "p90"
}

new const g_WeaponName[MAX_WEAPONS][] =
{
	"P228", "Scout", "HE Grenade", "XM1014", "C4",
	"MAC10", "AUG", "Smoke Grenade", "Dual Elite", "FiveSeven",
	"UMP45", "SG550", "Galil", "Famas", "USP",
	"Glock18", "AWP", "MP5", "M249", "M3",
	"M4A1", "TMP", "G3SG1", "Flashbang", "Deagle",
	"SG552", "AK47", "Knife", "P90"
}

new const g_WeaponClass[MAX_WEAPONS][] =
{
	"weapon_p228", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4",
	"weapon_mac10", "weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven",
	"weapon_ump45", "weapon_sg550", "weapon_galil", "weapon_famas", "weapon_usp",
	"weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249", "weapon_m3",
	"weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle",
	"weapon_sg552", "weapon_ak47", "weapon_knife", "weapon_p90"
}

new const g_WeaponCSW[MAX_WEAPONS] =
{
	CSW_P228, CSW_SCOUT, CSW_HEGRENADE, CSW_XM1014, CSW_C4,
	CSW_MAC10, CSW_AUG, CSW_SMOKEGRENADE, CSW_ELITE, CSW_FIVESEVEN,
	CSW_UMP45, CSW_SG550, CSW_GALIL, CSW_FAMAS, CSW_USP,
	CSW_GLOCK18, CSW_AWP, CSW_MP5NAVY, CSW_M249, CSW_M3,
	CSW_M4A1, CSW_TMP, CSW_G3SG1, CSW_FLASHBANG, CSW_DEAGLE,
	CSW_SG552, CSW_AK47, CSW_KNIFE, CSW_P90
}

new g_SkinName[MAX_WEAPONS][MAX_SKINS][MAX_SKIN_NAME]
new g_ViewModel[MAX_WEAPONS][MAX_SKINS][MAX_MODEL]
new g_PlayerModel[MAX_WEAPONS][MAX_SKINS][MAX_MODEL]
new g_WorldModel[MAX_WEAPONS][MAX_SKINS][MAX_MODEL]
new g_Description[MAX_WEAPONS][MAX_SKINS][MAX_DESC]
new g_SkinFlags[MAX_WEAPONS][MAX_SKINS][MAX_FLAGS]
new g_VipText[MAX_WEAPONS][MAX_SKINS][MAX_SKIN_NAME]

new bool:g_HasPlayerModel[MAX_WEAPONS][MAX_SKINS]
new bool:g_HasWorldModel[MAX_WEAPONS][MAX_SKINS]

new g_SkinCount[MAX_WEAPONS]
new g_Selected[33][MAX_WEAPONS]
new g_CarriedSkin[33][MAX_WEAPONS]
new g_LastWeaponMenu[33]

new bool:g_IsWarmup

new g_SaveSkins = 1
new g_SaveType = 2
new g_HideOnlySkin = 0
new g_MenuReopen = 1
new g_SpawnOnly = 0
new g_MenuFlags[MAX_FLAGS]
new g_ChatPrefix[MAX_PREFIX] = "$3[$4Skins Ultimate$3]"

new g_Vault = INVALID_HANDLE
new g_SayText

public plugin_precache()
{
	LoadSettings()
	LoadSkins()
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	g_SayText = get_user_msgid("SayText")

	RegisterCommands()
	RegisterWeaponHooks()

	register_forward(FM_SetModel, "Forward_SetModel", 1)
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	RegisterHam(Ham_Spawn, "player", "Ham_PlayerSpawn_Post", 1)

	register_message(get_user_msgid("TextMsg"), "Message_TextMsg")

	g_Vault = nvault_open("skins_ultimate_lite")
}

public plugin_end()
{
	if(g_Vault != INVALID_HANDLE)
		nvault_close(g_Vault)
}

public client_connect(id)
{
	for(new i = 0; i < MAX_WEAPONS; i++)
	{
		g_Selected[id][i] = 0
		g_CarriedSkin[id][i] = NO_SKIN
	}

	g_LastWeaponMenu[id] = -1
	remove_task(id + TASK_APPLY_SKIN)
	remove_task(id + TASK_WARMUP_FIX)
}

public client_disconnected(id)
{
	SavePlayerData(id)
	remove_task(id + TASK_APPLY_SKIN)
	remove_task(id + TASK_WARMUP_FIX)
}

public client_authorized(id)
{
	LoadPlayerData(id)
}

public Message_TextMsg(msgid, dest, id)
{
	static message[64]
	get_msg_arg_string(2, message, charsmax(message))

	if(equal(message, "#Game_Commencing"))
	{
		g_IsWarmup = true
	}
	else if(equal(message, "#Game_will_restart_in"))
	{
		g_IsWarmup = false
	}
}

RegisterCommands()
{
	register_clcmd("say /skins", "Cmd_MainMenu")
	register_clcmd("say_team /skins", "Cmd_MainMenu")
	register_clcmd("say /skin", "Cmd_MainMenu")
	register_clcmd("say_team /skin", "Cmd_MainMenu")
	register_clcmd("nightvision", "Cmd_MainMenu")

	new cmd[64]

	for(new i = 0; i < MAX_WEAPONS; i++)
	{
		formatex(cmd, charsmax(cmd), "say /%s", g_WeaponSection[i])
		register_clcmd(cmd, "Cmd_WeaponMenu")

		formatex(cmd, charsmax(cmd), "say_team /%s", g_WeaponSection[i])
		register_clcmd(cmd, "Cmd_WeaponMenu")
	}

	register_clcmd("say /ak", "Cmd_Ak")
	register_clcmd("say /m4", "Cmd_M4")
	register_clcmd("say /dgl", "Cmd_Dgl")
}

RegisterWeaponHooks()
{
	for(new i = 0; i < MAX_WEAPONS; i++)
	{
		RegisterHam(Ham_Item_AddToPlayer, g_WeaponClass[i], "Ham_Item_AddToPlayer_Post", 1)
		RegisterHam(Ham_Item_Deploy, g_WeaponClass[i], "Ham_Item_Deploy_Post", 1)
	}
}

public Cmd_MainMenu(id)
{
	ShowMainMenu(id)
	return PLUGIN_HANDLED
}

public Cmd_Ak(id)
{
	ShowWeaponMenuBySection(id, "ak47")
	return PLUGIN_HANDLED
}

public Cmd_M4(id)
{
	ShowWeaponMenuBySection(id, "m4a1")
	return PLUGIN_HANDLED
}

public Cmd_Dgl(id)
{
	ShowWeaponMenuBySection(id, "deagle")
	return PLUGIN_HANDLED
}

public Cmd_WeaponMenu(id)
{
	new args[64]
	read_args(args, charsmax(args))
	remove_quotes(args)
	trim(args)

	if(args[0] == '/')
		ShowWeaponMenuBySection(id, args[1])

	return PLUGIN_HANDLED
}

public Ham_PlayerSpawn_Post(id)
{
	if(!is_user_alive(id))
		return HAM_IGNORED

	remove_task(id + TASK_APPLY_SKIN)
	remove_task(id + TASK_WARMUP_FIX)

	if(g_IsWarmup)
	{
		set_task(0.05, "Task_WarmupKnifeModel", id + TASK_WARMUP_FIX)
		return HAM_IGNORED
	}

	set_task(0.2, "Task_ApplySkin", id + TASK_APPLY_SKIN)
	return HAM_IGNORED
}

public Event_CurWeapon(id)
{
	if(!is_user_alive(id) || g_SpawnOnly)
		return PLUGIN_CONTINUE

	remove_task(id + TASK_APPLY_SKIN)
	remove_task(id + TASK_WARMUP_FIX)

	if(g_IsWarmup)
	{
		set_task(0.02, "Task_WarmupKnifeModel", id + TASK_WARMUP_FIX)
		set_task(0.12, "Task_WarmupKnifeModel", id + TASK_WARMUP_FIX)
		return PLUGIN_CONTINUE
	}

	set_task(0.05, "Task_ApplySkin", id + TASK_APPLY_SKIN)
	return PLUGIN_CONTINUE
}

public Task_ApplySkin(taskid)
{
	new id = taskid - TASK_APPLY_SKIN

	if(is_user_alive(id))
		ApplyCurrentSkin(id)
}

public Task_WarmupKnifeModel(taskid)
{
	new id = taskid - TASK_WARMUP_FIX

	if(!is_user_alive(id) || !g_IsWarmup)
		return

	set_pev(id, pev_viewmodel2, "models/v_knife.mdl")
	set_pev(id, pev_weaponmodel2, "models/p_knife.mdl")
}

public Ham_Item_AddToPlayer_Post(ent, id)
{
	if(!pev_valid(ent) || !is_user_connected(id))
		return HAM_IGNORED

	new weaponIndex = GetWeaponIndexByEntity(ent)

	if(weaponIndex == -1)
		return HAM_IGNORED

	if(g_WeaponCSW[weaponIndex] == CSW_KNIFE)
		return HAM_IGNORED

	new skinIndex = NO_SKIN

	if(pev(ent, pev_iuser3) == SKIN_MAGIC)
		skinIndex = pev(ent, pev_iuser4)

	if(skinIndex >= 0 && skinIndex < g_SkinCount[weaponIndex])
		g_CarriedSkin[id][weaponIndex] = skinIndex
	else
		g_CarriedSkin[id][weaponIndex] = g_Selected[id][weaponIndex]

	set_pev(ent, pev_iuser3, SKIN_MAGIC)
	set_pev(ent, pev_iuser4, g_CarriedSkin[id][weaponIndex])

	return HAM_IGNORED
}

public Ham_Item_Deploy_Post(ent)
{
	if(!pev_valid(ent))
		return HAM_IGNORED

	new id = pev(ent, pev_owner)

	if(!is_user_alive(id))
		return HAM_IGNORED

	new weaponIndex = GetWeaponIndexByEntity(ent)

	if(weaponIndex == -1)
		return HAM_IGNORED

	if(g_IsWarmup)
	{
		remove_task(id + TASK_APPLY_SKIN)
		remove_task(id + TASK_WARMUP_FIX)
		set_task(0.02, "Task_WarmupKnifeModel", id + TASK_WARMUP_FIX)
		set_task(0.12, "Task_WarmupKnifeModel", id + TASK_WARMUP_FIX)
		return HAM_IGNORED
	}

	if(g_WeaponCSW[weaponIndex] == CSW_KNIFE)
	{
		g_CarriedSkin[id][weaponIndex] = g_Selected[id][weaponIndex]
		remove_task(id + TASK_APPLY_SKIN)
		set_task(0.05, "Task_ApplySkin", id + TASK_APPLY_SKIN)
		return HAM_IGNORED
	}

	if(pev(ent, pev_iuser3) == SKIN_MAGIC)
	{
		new skinIndex = pev(ent, pev_iuser4)

		if(skinIndex >= 0 && skinIndex < g_SkinCount[weaponIndex])
			g_CarriedSkin[id][weaponIndex] = skinIndex
	}

	remove_task(id + TASK_APPLY_SKIN)
	set_task(0.05, "Task_ApplySkin", id + TASK_APPLY_SKIN)

	return HAM_IGNORED
}

public Forward_SetModel(ent, const model[])
{
	if(!pev_valid(ent))
		return FMRES_IGNORED

	new classname[32]
	pev(ent, pev_classname, classname, charsmax(classname))

	if(!equal(classname, "weaponbox"))
		return FMRES_IGNORED

	new weaponEnt, weaponIndex
	weaponEnt = FindWeaponInBox(ent, weaponIndex)

	if(!pev_valid(weaponEnt) || weaponIndex == -1)
		return FMRES_IGNORED

	new owner = pev(ent, pev_owner)
	new skinIndex = 0

	if(is_user_connected(owner))
	{
		if(g_CarriedSkin[owner][weaponIndex] >= 0)
			skinIndex = g_CarriedSkin[owner][weaponIndex]
		else
			skinIndex = g_Selected[owner][weaponIndex]
	}
	else if(pev(weaponEnt, pev_iuser3) == SKIN_MAGIC)
	{
		skinIndex = pev(weaponEnt, pev_iuser4)
	}

	if(skinIndex < 0 || skinIndex >= g_SkinCount[weaponIndex])
		skinIndex = 0

	set_pev(weaponEnt, pev_iuser3, SKIN_MAGIC)
	set_pev(weaponEnt, pev_iuser4, skinIndex)

	set_pev(ent, pev_iuser3, SKIN_MAGIC)
	set_pev(ent, pev_iuser4, skinIndex)
	set_pev(ent, pev_iuser2, weaponIndex)

	if(g_HasWorldModel[weaponIndex][skinIndex])
	{
		engfunc(EngFunc_SetModel, ent, g_WorldModel[weaponIndex][skinIndex])
		return FMRES_SUPERCEDE
	}

	return FMRES_IGNORED
}

FindWeaponInBox(box, &weaponIndex)
{
	new ent = -1

	for(new i = 0; i < MAX_WEAPONS; i++)
	{
		ent = -1

		while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", g_WeaponClass[i])) > 0)
		{
			if(pev_valid(ent) && pev(ent, pev_owner) == box)
			{
				weaponIndex = i
				return ent
			}
		}
	}

	weaponIndex = -1
	return 0
}

ShowMainMenu(id)
{
	if(!CanOpenMenu(id))
	{
		ColorChat(id, "%s $1You do not have access to this menu.", g_ChatPrefix)
		return
	}

	new menu = menu_create("\y>>>>> \rSkins Ultimate \y<<<<<", "MainMenu_Handler")

	new data[8], item[128]
	new currentWeapon = GetWeaponIndexByCSW(get_user_weapon(id))

	for(new i = 0; i < MAX_WEAPONS; i++)
	{
		if(g_SkinCount[i] <= 0)
			continue

		if(g_HideOnlySkin && g_SkinCount[i] <= 1)
			continue

		num_to_str(i, data, charsmax(data))

		if(i == currentWeapon)
			formatex(item, charsmax(item), "\r* \y%s \d[%d]", g_WeaponName[i], g_SkinCount[i])
		else
			formatex(item, charsmax(item), "\w%s \d[%d]", g_WeaponName[i], g_SkinCount[i])

		menu_additem(menu, item, data)
	}

	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
	menu_display(id, menu, 0)
}

public MainMenu_Handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	new data[8], name[64], access, callback
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback)

	new weaponIndex = str_to_num(data)

	menu_destroy(menu)
	ShowWeaponMenu(id, weaponIndex)

	return PLUGIN_HANDLED
}

ShowWeaponMenuBySection(id, const section[])
{
	new weaponIndex = GetWeaponIndexBySection(section)

	if(weaponIndex == -1)
	{
		ColorChat(id, "%s $1Unknown weapon.", g_ChatPrefix)
		return
	}

	ShowWeaponMenu(id, weaponIndex)
}

ShowWeaponMenu(id, weaponIndex)
{
	if(weaponIndex < 0 || weaponIndex >= MAX_WEAPONS)
		return

	if(g_SkinCount[weaponIndex] <= 0)
	{
		ColorChat(id, "%s $1No skins loaded for $4%s$1.", g_ChatPrefix, g_WeaponName[weaponIndex])
		return
	}

	g_LastWeaponMenu[id] = weaponIndex

	new title[128]
	formatex(title, charsmax(title), "\y>>>>> \r%s Skins \y<<<<<", g_WeaponName[weaponIndex])

	new menu = menu_create(title, "WeaponMenu_Handler")

	new data[8], itemText[192], desc[96]
	new currentWeapon = GetWeaponIndexByCSW(get_user_weapon(id))
	new currentSkin = GetActiveSkin(id, weaponIndex)

	for(new i = 0; i < g_SkinCount[weaponIndex]; i++)
	{
		num_to_str(i, data, charsmax(data))

		desc[0] = 0

		if(g_Description[weaponIndex][i][0])
			formatex(desc, charsmax(desc), " %s", g_Description[weaponIndex][i])

		new bool:access = HasSkinAccess(id, weaponIndex, i)

		if(!access)
		{
			if(g_VipText[weaponIndex][i][0])
				formatex(itemText, charsmax(itemText), "\d%s%s \r%s", g_SkinName[weaponIndex][i], desc, g_VipText[weaponIndex][i])
			else
				formatex(itemText, charsmax(itemText), "\d%s%s \r[LOCKED]", g_SkinName[weaponIndex][i], desc)
		}
		else if(currentWeapon == weaponIndex && currentSkin == i)
		{
			formatex(itemText, charsmax(itemText), "\y%s%s \r< CURRENT >", g_SkinName[weaponIndex][i], desc)
		}
		else if(g_Selected[id][weaponIndex] == i)
		{
			formatex(itemText, charsmax(itemText), "\y%s%s \d< SELECT >", g_SkinName[weaponIndex][i], desc)
		}
		else
		{
			formatex(itemText, charsmax(itemText), "\w%s%s", g_SkinName[weaponIndex][i], desc)
		}

		menu_additem(menu, itemText, data)
	}

	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
	menu_display(id, menu, 0)
}

public WeaponMenu_Handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	new weaponIndex = g_LastWeaponMenu[id]

	if(weaponIndex < 0 || weaponIndex >= MAX_WEAPONS)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	new data[8], name[64], access, callback
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback)

	new skinIndex = str_to_num(data)

	if(skinIndex < 0 || skinIndex >= g_SkinCount[weaponIndex])
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	if(!HasSkinAccess(id, weaponIndex, skinIndex))
	{
		ColorChat(id, "%s $1This skin is locked.", g_ChatPrefix)

		menu_destroy(menu)

		if(g_MenuReopen)
			ShowWeaponMenu(id, weaponIndex)

		return PLUGIN_HANDLED
	}

	g_Selected[id][weaponIndex] = skinIndex

	if(GetWeaponIndexByCSW(get_user_weapon(id)) == weaponIndex)
	{
		g_CarriedSkin[id][weaponIndex] = skinIndex
		SetCurrentWeaponEntitySkin(id, weaponIndex, skinIndex)

		if(!g_SpawnOnly && !g_IsWarmup)
			ApplyWeaponSkin(id, weaponIndex)
	}

	SavePlayerWeapon(id, weaponIndex)

	ColorChat(id, "%s $1Selected $4%s $1for $3%s$1.", g_ChatPrefix, g_SkinName[weaponIndex][skinIndex], g_WeaponName[weaponIndex])

	menu_destroy(menu)

	if(g_MenuReopen)
		ShowWeaponMenu(id, weaponIndex)

	return PLUGIN_HANDLED
}

SetCurrentWeaponEntitySkin(id, weaponIndex, skinIndex)
{
	new ent = GetPlayerWeaponEntity(id, g_WeaponClass[weaponIndex])

	if(pev_valid(ent))
	{
		set_pev(ent, pev_iuser3, SKIN_MAGIC)
		set_pev(ent, pev_iuser4, skinIndex)
	}
}

GetPlayerWeaponEntity(id, const weaponClass[])
{
	new ent = -1

	while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", weaponClass)) > 0)
	{
		if(pev_valid(ent) && pev(ent, pev_owner) == id)
			return ent
	}

	return 0
}

ApplyCurrentSkin(id)
{
	if(!is_user_alive(id))
		return

	if(g_IsWarmup)
	{
		set_pev(id, pev_viewmodel2, "models/v_knife.mdl")
		set_pev(id, pev_weaponmodel2, "models/p_knife.mdl")
		return
	}

	new csw = get_user_weapon(id)

	if(csw == CSW_KNIFE)
	{
		new knifeIndex = GetWeaponIndexByCSW(CSW_KNIFE)

		if(knifeIndex != -1 && g_SkinCount[knifeIndex] > 0)
			ApplyWeaponSkin(id, knifeIndex)
		else
		{
			set_pev(id, pev_viewmodel2, "models/v_knife.mdl")
			set_pev(id, pev_weaponmodel2, "models/p_knife.mdl")
		}

		return
	}

	new weaponIndex = GetWeaponIndexByCSW(csw)

	if(weaponIndex == -1)
		return

	ApplyWeaponSkin(id, weaponIndex)
}

ApplyWeaponSkin(id, weaponIndex)
{
	if(g_IsWarmup)
	{
		set_pev(id, pev_viewmodel2, "models/v_knife.mdl")
		set_pev(id, pev_weaponmodel2, "models/p_knife.mdl")
		return
	}

	if(!is_user_alive(id))
		return

	if(weaponIndex < 0 || weaponIndex >= MAX_WEAPONS)
		return

	new currentCsw = get_user_weapon(id)
	new currentWeapon = GetWeaponIndexByCSW(currentCsw)

	if(currentWeapon != weaponIndex)
		return

	if(currentCsw == CSW_KNIFE && g_WeaponCSW[weaponIndex] != CSW_KNIFE)
		return

	new skinIndex = GetActiveSkin(id, weaponIndex)

	if(skinIndex < 0 || skinIndex >= g_SkinCount[weaponIndex])
		skinIndex = 0

	if(!HasSkinAccess(id, weaponIndex, skinIndex))
		skinIndex = 0

	if(!g_ViewModel[weaponIndex][skinIndex][0])
	{
		if(g_WeaponCSW[weaponIndex] == CSW_KNIFE)
		{
			set_pev(id, pev_viewmodel2, "models/v_knife.mdl")
			set_pev(id, pev_weaponmodel2, "models/p_knife.mdl")
		}
		return
	}

	set_pev(id, pev_viewmodel2, g_ViewModel[weaponIndex][skinIndex])

	if(g_HasPlayerModel[weaponIndex][skinIndex])
		set_pev(id, pev_weaponmodel2, g_PlayerModel[weaponIndex][skinIndex])
	else if(g_WeaponCSW[weaponIndex] == CSW_KNIFE)
		set_pev(id, pev_weaponmodel2, "models/p_knife.mdl")
}

GetActiveSkin(id, weaponIndex)
{
	if(g_WeaponCSW[weaponIndex] == CSW_KNIFE)
		return g_Selected[id][weaponIndex]

	if(g_CarriedSkin[id][weaponIndex] >= 0)
		return g_CarriedSkin[id][weaponIndex]

	return g_Selected[id][weaponIndex]
}

LoadSettings()
{
	new configs[128], path[192]
	get_localinfo("amxx_configsdir", configs, charsmax(configs))
	formatex(path, charsmax(path), "%s/weapons_skins_ultimate/wsu_settings.ini", configs)

	new file = fopen(path, "rt")

	if(!file)
	{
		server_print("[Skins Ultimate] Settings file not found: %s", path)
		return
	}

	new line[256], key[64], value[192]

	while(!feof(file))
	{
		fgets(file, line, charsmax(line))
		trim(line)

		if(!line[0] || line[0] == '#' || line[0] == ';')
			continue

		new equal = contain(line, "=")

		if(equal == -1)
			continue

		copy(key, charsmax(key), line)
		key[equal] = 0

		copy(value, charsmax(value), line[equal + 1])

		trim(key)
		trim(value)

		if(equali(key, "SAVE_SKINS"))
			g_SaveSkins = str_to_num(value)
		else if(equali(key, "SAVE_TYPE"))
			g_SaveType = str_to_num(value)
		else if(equali(key, "MENU_FLAGS"))
			copy(g_MenuFlags, charsmax(g_MenuFlags), value)
		else if(equali(key, "HIDE_ONLY_SKIN"))
			g_HideOnlySkin = str_to_num(value)
		else if(equali(key, "MENU_REOPEN"))
			g_MenuReopen = str_to_num(value)
		else if(equali(key, "SPAWN_ONLY"))
			g_SpawnOnly = str_to_num(value)
		else if(equali(key, "CHAT_PREFIX"))
			copy(g_ChatPrefix, charsmax(g_ChatPrefix), value)
	}

	fclose(file)
}

LoadSkins()
{
	new configs[128], path[192]
	get_localinfo("amxx_configsdir", configs, charsmax(configs))
	formatex(path, charsmax(path), "%s/weapons_skins_ultimate/wsu_skins.ini", configs)

	new file = fopen(path, "rt")

	if(!file)
	{
		server_print("[Skins Ultimate] Skins file not found: %s", path)
		return
	}

	new line[256]
	new currentWeapon = -1
	new lastSkin = -1

	while(!feof(file))
	{
		fgets(file, line, charsmax(line))
		trim(line)

		if(!line[0] || line[0] == '#' || line[0] == ';')
			continue

		if(line[0] == '[')
		{
			new section[64]
			copy(section, charsmax(section), line[1])

			new end = contain(section, "]")
			if(end != -1)
				section[end] = 0

			trim(section)

			currentWeapon = GetWeaponIndexBySection(section)
			lastSkin = -1
			continue
		}

		if(currentWeapon == -1)
			continue

		if(line[0] == '-')
		{
			if(lastSkin != -1)
				ParseAttribute(currentWeapon, lastSkin, line)

			continue
		}

		new equal = contain(line, "=")

		if(equal == -1)
			continue

		new skinName[MAX_SKIN_NAME], modelPath[MAX_MODEL]

		copy(skinName, charsmax(skinName), line)
		skinName[equal] = 0

		copy(modelPath, charsmax(modelPath), line[equal + 1])

		trim(skinName)
		trim(modelPath)

		if(!skinName[0] || !modelPath[0])
			continue

		new count = g_SkinCount[currentWeapon]

		if(count >= MAX_SKINS)
		{
			server_print("[Skins Ultimate] Too many skins in [%s]", g_WeaponSection[currentWeapon])
			continue
		}

		copy(g_SkinName[currentWeapon][count], MAX_SKIN_NAME - 1, skinName)
		PrepareModels(currentWeapon, count, modelPath)

		g_SkinCount[currentWeapon]++
		lastSkin = count
	}

	fclose(file)

	for(new i = 0; i < MAX_WEAPONS; i++)
	{
		if(g_SkinCount[i] > 0)
			server_print("[Skins Ultimate] Loaded %d skins for [%s]", g_SkinCount[i], g_WeaponSection[i])
	}
}

ParseAttribute(weaponIndex, skinIndex, const line[])
{
	new buffer[256]
	copy(buffer, charsmax(buffer), line[1])
	trim(buffer)

	new equal = contain(buffer, "=")

	if(equal == -1)
		return

	new attr[64], value[192]

	copy(attr, charsmax(attr), buffer)
	attr[equal] = 0

	copy(value, charsmax(value), buffer[equal + 1])

	trim(attr)
	trim(value)

	if(equali(attr, "DESCRIPTION"))
		copy(g_Description[weaponIndex][skinIndex], MAX_DESC - 1, value)
	else if(equali(attr, "FLAGS"))
		copy(g_SkinFlags[weaponIndex][skinIndex], MAX_FLAGS - 1, value)
	else if(equali(attr, "VIPTEXT"))
		copy(g_VipText[weaponIndex][skinIndex], MAX_SKIN_NAME - 1, value)
}

PrepareModels(weaponIndex, skinIndex, const modelPath[])
{
	if(contain(modelPath, "@") != -1)
	{
		new vModel[MAX_MODEL], pModel[MAX_MODEL], wModel[MAX_MODEL]

		copy(vModel, charsmax(vModel), modelPath)
		copy(pModel, charsmax(pModel), modelPath)
		copy(wModel, charsmax(wModel), modelPath)

		replace(vModel, charsmax(vModel), "@", "v_")
		replace(pModel, charsmax(pModel), "@", "p_")
		replace(wModel, charsmax(wModel), "@", "w_")

		copy(g_ViewModel[weaponIndex][skinIndex], MAX_MODEL - 1, vModel)
		copy(g_PlayerModel[weaponIndex][skinIndex], MAX_MODEL - 1, pModel)
		copy(g_WorldModel[weaponIndex][skinIndex], MAX_MODEL - 1, wModel)

		PrecacheModelSafe(vModel)

		if(PrecacheModelSafe(pModel))
			g_HasPlayerModel[weaponIndex][skinIndex] = true

		if(PrecacheModelSafe(wModel))
			g_HasWorldModel[weaponIndex][skinIndex] = true
	}
	else
	{
		copy(g_ViewModel[weaponIndex][skinIndex], MAX_MODEL - 1, modelPath)
		PrecacheModelSafe(modelPath)
	}
}

bool:PrecacheModelSafe(const model[])
{
	if(!model[0])
		return false

	if(!file_exists(model))
	{
		server_print("[Skins Ultimate] Missing model: %s", model)
		return false
	}

	precache_model(model)
	return true
}

bool:CanOpenMenu(id)
{
	if(!g_MenuFlags[0])
		return true

	new need = read_flags(g_MenuFlags)
	new have = get_user_flags(id)

	return bool:((have & need) == need)
}

bool:HasSkinAccess(id, weaponIndex, skinIndex)
{
	if(!g_SkinFlags[weaponIndex][skinIndex][0])
		return true

	new need = read_flags(g_SkinFlags[weaponIndex][skinIndex])
	new have = get_user_flags(id)

	return bool:((have & need) == need)
}

SavePlayerData(id)
{
	if(!g_SaveSkins || g_Vault == INVALID_HANDLE)
		return

	for(new i = 0; i < MAX_WEAPONS; i++)
		SavePlayerWeapon(id, i)
}

SavePlayerWeapon(id, weaponIndex)
{
	if(!g_SaveSkins || g_Vault == INVALID_HANDLE)
		return

	new key[128], value[16]
	GetSaveKey(id, weaponIndex, key, charsmax(key))

	num_to_str(g_Selected[id][weaponIndex], value, charsmax(value))
	nvault_set(g_Vault, key, value)
}

LoadPlayerData(id)
{
	if(!g_SaveSkins || g_Vault == INVALID_HANDLE)
		return

	new key[128], value[16]

	for(new i = 0; i < MAX_WEAPONS; i++)
	{
		GetSaveKey(id, i, key, charsmax(key))

		if(nvault_get(g_Vault, key, value, charsmax(value)))
		{
			new skin = str_to_num(value)

			if(skin >= 0 && skin < g_SkinCount[i])
				g_Selected[id][i] = skin
			else
				g_Selected[id][i] = 0
		}
	}
}

GetSaveKey(id, weaponIndex, key[], len)
{
	new auth[64]

	switch(g_SaveType)
	{
		case 0:
		{
			get_user_name(id, auth, charsmax(auth))
		}
		case 1:
		{
			get_user_ip(id, auth, charsmax(auth), 1)
		}
		default:
		{
			get_user_authid(id, auth, charsmax(auth))
		}
	}

	formatex(key, len, "%s_%s", auth, g_WeaponSection[weaponIndex])
}

GetWeaponIndexBySection(const section[])
{
	for(new i = 0; i < MAX_WEAPONS; i++)
	{
		if(equali(section, g_WeaponSection[i]))
			return i
	}

	return -1
}

GetWeaponIndexByCSW(csw)
{
	for(new i = 0; i < MAX_WEAPONS; i++)
	{
		if(g_WeaponCSW[i] == csw)
			return i
	}

	return -1
}

GetWeaponIndexByEntity(ent)
{
	if(!pev_valid(ent))
		return -1

	new classname[32]
	pev(ent, pev_classname, classname, charsmax(classname))

	for(new i = 0; i < MAX_WEAPONS; i++)
	{
		if(equal(classname, g_WeaponClass[i]))
			return i
	}

	return -1
}

ColorChat(id, const input[], any:...)
{
	new message[192]
	vformat(message, charsmax(message), input, 3)

	replace_all(message, charsmax(message), "$1", "^1")
	replace_all(message, charsmax(message), "$3", "^3")
	replace_all(message, charsmax(message), "$4", "^4")

	if(id)
	{
		message_begin(MSG_ONE_UNRELIABLE, g_SayText, _, id)
		write_byte(id)
		write_string(message)
		message_end()
	}
	else
	{
		for(new i = 1; i <= 32; i++)
		{
			if(!is_user_connected(i))
				continue

			message_begin(MSG_ONE_UNRELIABLE, g_SayText, _, i)
			write_byte(i)
			write_string(message)
			message_end()
		}
	}
}
