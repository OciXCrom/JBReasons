#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <hamsandwich>

#define CC_COLORS_TYPE CC_COLORS_SHORT
#include <cromchat>

#define PLUGIN_VERSION "1.4"

new g_iVictim[33], g_iArraySize
new g_cvCustom, g_cvDeny, g_cvExit
new Array:g_aJailReasons

public plugin_init()
{
	register_plugin("JB: Reasons Menu", PLUGIN_VERSION, "OciXCrom")
	register_cvar("JailReasons", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	register_dictionary("JailReasons.txt")
	register_event("DeathMsg", "OnPlayerKilled", "a")
	register_clcmd("jailReason", "Cmd_JailReasons")
	register_clcmd("nightvision", "Cmd_Deny")
	register_impulse(201, "Cmd_Custom")
	g_cvCustom = register_cvar("jbreasons_custom", "1")
	g_cvDeny = register_cvar("jbreasons_deny", "2")
	g_cvExit = register_cvar("jbreasons_exit", "1")
	g_aJailReasons = ArrayCreate(128, 32)
	CC_SetPrefix("[!gJB: Reasons!n]")
	fileRead()
}

public plugin_end()
	ArrayDestroy(g_aJailReasons)

fileRead()
{
	new szConfigsName[256], szFilename[256]
	get_configsdir(szConfigsName, charsmax(szConfigsName))
	formatex(szFilename, charsmax(szFilename), "%s/JailReasons.ini", szConfigsName)
	new iFilePointer = fopen(szFilename, "rt")
	
	if(iFilePointer)
	{
		new szData[128]
		
		while(!feof(iFilePointer))
		{
			fgets(iFilePointer, szData, charsmax(szData))
			trim(szData)
			
			if(szData[0] == EOS || szData[0] == ';')
				continue
				
			ArrayPushString(g_aJailReasons, szData)
		}
		
		g_iArraySize = ArraySize(g_aJailReasons)
		fclose(iFilePointer)
	}
}

public ReasonsMenu(id)
{
	new szTitle[256], szItem[128], szName[32]
	get_user_name(g_iVictim[id], szName, charsmax(szName))
	formatex(szTitle, charsmax(szTitle), "%L", LANG_PLAYER, "JBR_TITLE_WHY", szName)
	
	if(get_pcvar_num(g_cvCustom))
	{
		formatex(szItem, charsmax(szItem), "%L", LANG_PLAYER, "JBR_TITLE_CUSTOM")
		add(szTitle, charsmax(szTitle), szItem)
	}
	
	if(get_pcvar_num(g_cvDeny))
	{
		formatex(szItem, charsmax(szItem), "%L", LANG_PLAYER, "JBR_TITLE_DENY")
		add(szTitle, charsmax(szTitle), szItem)
	}
	
	new iMenu = menu_create(szTitle, "Handler_ReasonsMenu")
	
	for(new i; i < g_iArraySize; i++)
	{
		ArrayGetString(g_aJailReasons, i, szItem, charsmax(szItem))
		menu_additem(iMenu, szItem, "", 0)
	}
	
	formatex(szItem, charsmax(szItem), "%L", LANG_PLAYER, "JBR_MENU_BACK")
	menu_setprop(iMenu, MPROP_BACKNAME, szItem)
	formatex(szItem, charsmax(szItem), "%L", LANG_PLAYER, "JBR_MENU_NEXT")
	menu_setprop(iMenu, MPROP_NEXTNAME, szItem)
	
	if(get_pcvar_num(g_cvExit)) menu_setprop(iMenu, MEXIT_ALL, 0)
	else
	{
		formatex(szItem, charsmax(szItem), "%L", LANG_PLAYER, "JBR_MENU_EXIT")
		menu_setprop(iMenu, MPROP_EXITNAME, szItem)
	}
	
	menu_display(id, iMenu, 0)
	return PLUGIN_HANDLED
}

public Handler_ReasonsMenu(id, iMenu, iItem)
{
	new szReason[64], szName[32]
	get_user_name(id, szName, charsmax(szName))
	ArrayGetString(g_aJailReasons, iItem, szReason, charsmax(szReason))
	ShowReason(id, szReason)
	menu_destroy(iMenu)
	return PLUGIN_HANDLED
}

public OnPlayerKilled()
{
	new iAttacker = read_data(1), iVictim = read_data(2)
	
	if(is_user_connected(iAttacker) && is_user_connected(iVictim))
	{
		if(get_user_team(iAttacker) == 2 && get_user_team(iVictim) == 1)
		{
			g_iVictim[iAttacker] = iVictim
			DestroyMenu(iAttacker)
			ReasonsMenu(iAttacker)
		}
	}
}

public Cmd_Custom(id)
{
	if(get_user_team(id) == 2 && has_access(id) && get_pcvar_num(g_cvCustom))
	{
		DestroyMenu(id)
		client_cmd(id, "messagemode jailReason")
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

public Cmd_Deny(id)
{
	new iCvar = get_pcvar_num(g_cvDeny)
	
	if(get_user_team(id) == 2 && has_access(id) && iCvar)
	{
		new szName[32], szName2[32]
		get_user_name(id, szName, charsmax(szName))
		get_user_name(g_iVictim[id], szName2, charsmax(szName2))
		CC_SendMessage(0, "%L", LANG_PLAYER, "JBR_KILL_DENY", szName, szName2, LANG_PLAYER, (iCvar > 1) ? "JBR_KILL_REVIVE" : "JBR_KILL_SORRY")
		DestroyMenu(id)
		
		if(iCvar > 1 && get_user_team(g_iVictim[id]) == 1 && !is_user_alive(g_iVictim[id]))
			ExecuteHamB(Ham_CS_RoundRespawn, g_iVictim[id])
		
		g_iVictim[id] = 0
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

public Cmd_JailReasons(id)
{
	if(!has_access(id))
		return PLUGIN_HANDLED
		
	new szArgs[192]
	read_args(szArgs, charsmax(szArgs))
	remove_quotes(szArgs)
	
	if(szArgs[0] != EOS)
		ShowReason(id, szArgs)
		
	return PLUGIN_HANDLED
}

ShowReason(const id, const szReason[])
{
	new szName[32], szName2[32]
	get_user_name(id, szName, charsmax(szName))
	get_user_name(g_iVictim[id], szName2, charsmax(szName2))
	CC_SendMessage(0, "%L", LANG_PLAYER, "JBR_KILL_REASON", szName, szName2, szReason)
	g_iVictim[id] = 0
}

DestroyMenu(const id)
{
	new iNewMenu, iMenu = player_menu_info(id, iMenu, iNewMenu)
	
	if(iMenu)
		show_menu(id, 0, "^n", 1)
}
	
bool:has_access(const id)
	return bool:g_iVictim[id]