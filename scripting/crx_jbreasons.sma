#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <hamsandwich>

#define PLUGIN_VERSION "1.3"

enum Color
{
	NORMAL = 1, // clients scr_concolor cvar color
	GREEN, // Green Color
	TEAM_COLOR, // Red, grey, blue
	GREY, // grey
	RED, // Red
	BLUE, // Blue
}

new TeamName[][] = 
{
	"",
	"TERRORIST",
	"CT",
	"SPECTATOR"
}

new const g_szPrefix[] = "^1[^4JB: Reasons^1]"
new g_iVictim[33], g_iArraySize
new g_msgSayText, g_msgTeamInfo, g_iMaxPlayers
new g_cvCustom, g_cvDeny, g_cvExit
new Array:g_aJailReasons

public plugin_init()
{
	register_plugin("JB: Reasons Menu", PLUGIN_VERSION, "OciXCrom")
	register_cvar("JailReasons", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	register_dictionary("JailReasons.txt")
	register_event("DeathMsg", "eventPlayerKilled", "a")
	register_clcmd("jailReason", "cmdJailReason")
	register_clcmd("nightvision", "cmdDeny")
	register_impulse(201, "cmdCustom")
	g_cvCustom = register_cvar("jbreasons_custom", "1")
	g_cvDeny = register_cvar("jbreasons_deny", "2")
	g_cvExit = register_cvar("jbreasons_exit", "1")
	g_aJailReasons = ArrayCreate(128, 32)
	g_msgSayText = get_user_msgid("SayText")
	g_msgTeamInfo = get_user_msgid("TeamInfo")
	g_iMaxPlayers = get_maxplayers()
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

public menuReasons(id)
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
	
	new iMenu = menu_create(szTitle, "handlerReasons")
	
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

public handlerReasons(id, iMenu, iItem)
{
	if(iItem == MENU_EXIT) g_iVictim[id] = 0
	else
	{
		new szReason[64], szName[32]
		get_user_name(id, szName, charsmax(szName))
		ArrayGetString(g_aJailReasons, iItem, szReason, charsmax(szReason))
		showReason(id, szReason)
	}
	
	menu_destroy(iMenu)
	return PLUGIN_HANDLED
}	

public eventPlayerKilled()
{
	new iAttacker = read_data(1), iVictim = read_data(2)
	
	if(is_user_connected(iAttacker) && is_user_connected(iVictim))
	{
		if(get_user_team(iAttacker) == 2 && get_user_team(iVictim) == 1)
		{
			g_iVictim[iAttacker] = iVictim
			destroyMenu(iAttacker)
			menuReasons(iAttacker)
		}
	}
}

public cmdCustom(id)
{
	if(get_user_team(id) == 2 && has_access(id) && get_pcvar_num(g_cvCustom))
	{
		destroyMenu(id)
		client_cmd(id, "messagemode jailReason")
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

public cmdDeny(id)
{
	new iCvar = get_pcvar_num(g_cvDeny)
	
	if(get_user_team(id) == 2 && has_access(id) && iCvar)
	{
		new szName[32], szName2[32]
		get_user_name(id, szName, charsmax(szName))
		get_user_name(g_iVictim[id], szName2, charsmax(szName2))
		ColorChat(0, TEAM_COLOR, "%s %L", g_szPrefix, LANG_PLAYER, "JBR_KILL_DENY", szName, szName2, LANG_PLAYER, (iCvar > 1) ? "JBR_KILL_REVIVE" : "JBR_KILL_SORRY")
		destroyMenu(id)
		
		if(iCvar > 1 && get_user_team(g_iVictim[id]) == 1 && !is_user_alive(g_iVictim[id]))
			ExecuteHamB(Ham_CS_RoundRespawn, g_iVictim[id])
		
		g_iVictim[id] = 0
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

public cmdJailReason(id)
{
	if(!has_access(id))
		return PLUGIN_HANDLED
		
	new szArgs[192]
	read_args(szArgs, charsmax(szArgs))
	remove_quotes(szArgs)
	
	if(szArgs[0] != EOS)
		showReason(id, szArgs)
		
	return PLUGIN_HANDLED
}

showReason(id, szReason[])
{
	new szName[32], szName2[32]
	get_user_name(id, szName, charsmax(szName))
	get_user_name(g_iVictim[id], szName2, charsmax(szName2))
	ColorChat(0, TEAM_COLOR, "%s %L", g_szPrefix, LANG_PLAYER, "JBR_KILL_REASON", szName, szName2, szReason)
	g_iVictim[id] = 0
}

destroyMenu(id)
{
	new iNewMenu, iMenu = player_menu_info(id, iMenu, iNewMenu)
	
	if(iMenu)
		show_menu(id, 0, "^n", 1)
}
	
bool:has_access(id)
	return g_iVictim[id] ? true : false

ColorChat(id, Color:type, const msg[], {Float,Sql,Result,_}:...)
{
	static message[256];

	switch(type)
	{
		case NORMAL: // clients scr_concolor cvar color
		{
			message[0] = 0x01;
		}
		case GREEN: // Green
		{
			message[0] = 0x04;
		}
		default: // White, Red, Blue
		{
			message[0] = 0x03;
		}
	}

	vformat(message[1], charsmax(message) - 4, msg, 4);
	
	replace_all(message, charsmax(message), "!n", "^x01");
	replace_all(message, charsmax(message), "!t", "^x03");
	replace_all(message, charsmax(message), "!g", "^x04");

	// Make sure message is not longer than 192 character. Will crash the server.
	message[192] = '^0';

	static team, ColorChange, index, MSG_Type;
	
	if(id)
	{
		MSG_Type = MSG_ONE;
		index = id;
	} else {
		index = FindPlayer();
		MSG_Type = MSG_ALL;
	}
	
	team = get_user_team(index);
	ColorChange = ColorSelection(index, MSG_Type, type);

	ShowColorMessage(index, MSG_Type, message);
		
	if(ColorChange)
	{
		Team_Info(index, MSG_Type, TeamName[team]);
	}
}

ShowColorMessage(id, type, message[])
{
	message_begin(type, g_msgSayText, _, id);
	write_byte(id)		
	write_string(message);
	message_end();	
}

Team_Info(id, type, team[])
{
	message_begin(type, g_msgTeamInfo, _, id);
	write_byte(id);
	write_string(team);
	message_end();

	return 1;
}

ColorSelection(index, type, Color:Type)
{
	switch(Type)
	{
		case RED:
		{
			return Team_Info(index, type, TeamName[1]);
		}
		case BLUE:
		{
			return Team_Info(index, type, TeamName[2]);
		}
		case GREY:
		{
			return Team_Info(index, type, TeamName[0]);
		}
	}

	return 0;
}

FindPlayer()
{
	static i;
	i = -1;

	while(i <= g_iMaxPlayers)
	{
		if(is_user_connected(++i))
		{
			return i;
		}
	}

	return -1;
}