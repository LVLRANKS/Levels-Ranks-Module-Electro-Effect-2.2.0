#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <lvl_ranks>

#define PLUGIN_NAME "Levels Ranks"
#define PLUGIN_AUTHOR "RoadSide Romeo & R1KO"

int		g_iEELevel,
		g_iEEButton[MAXPLAYERS+1];
Handle	g_hElectroEffect = null;

public Plugin myinfo = {name = "[LR] Module - Electro Effect", author = PLUGIN_AUTHOR, version = PLUGIN_VERSION}
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch(GetEngineVersion())
	{
		case Engine_CSGO, Engine_CSS: LogMessage("[%s Electro Effect] Запущен успешно", PLUGIN_NAME);
		default: SetFailState("[%s Electro Effect] Плагин работает только на CS:GO и CS:S", PLUGIN_NAME);
	}
}

public void OnPluginStart()
{
	LR_ModuleCount();
	HookEvent("player_death", PlayerDeath);
	HookEvent("bullet_impact", BulletImpact);
	g_hElectroEffect = RegClientCookie("LR_ElectroEffect", "LR_ElectroEffect", CookieAccess_Private);
	LoadTranslations("levels_ranks_electroeffect.phrases");

	for(int iClient = 1; iClient <= MaxClients; iClient++)
    {
		if(IsClientInGame(iClient))
		{
			if(AreClientCookiesCached(iClient))
			{
				OnClientCookiesCached(iClient);
			}
		}
	}
}

public void OnMapStart() 
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/electroeffect.ini");
	KeyValues hLR_EE = new KeyValues("LR_ElectroEffect");

	if(!hLR_EE.ImportFromFile(sPath) || !hLR_EE.GotoFirstSubKey())
	{
		SetFailState("[%s Electro Effect] : фатальная ошибка - файл не найден (%s)", PLUGIN_NAME, sPath);
	}

	hLR_EE.Rewind();

	if(hLR_EE.JumpToKey("Settings"))
	{
		g_iEELevel = hLR_EE.GetNum("rank", 0);
	}
	else SetFailState("[%s Electro Effect] : фатальная ошибка - секция Settings не найдена", PLUGIN_NAME);
	delete hLR_EE;
}

public void PlayerDeath(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{
	int iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker")), iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(iAttacker != iClient && IsValidClient(iAttacker) && IsValidClient(iClient) && !g_iEEButton[iAttacker] && (LR_GetClientRank(iAttacker) >= g_iEELevel))
	{
		float fPos[3];
		GetClientAbsOrigin(iClient, fPos);
		MakeTeslaEffect(fPos);
	}
}

public void BulletImpact(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(IsValidClient(iClient) && !g_iEEButton[iClient] && (LR_GetClientRank(iClient) >= g_iEELevel))
	{
		float fPos[3];
		fPos[0] = GetEventFloat(hEvent, "x");
		fPos[1] = GetEventFloat(hEvent, "y");
		fPos[2] = GetEventFloat(hEvent, "z");
		MakeTeslaSplashEffect(fPos);
	}
}

void MakeTeslaSplashEffect(float fPos[3]) 
{
	float fEndPos[3];
	fEndPos[0] = fPos[0] + 20.0;
	fEndPos[1] = fPos[1] + 20.0;
	fEndPos[2] = fPos[2] + 20.0;
	TE_SetupEnergySplash(fPos, fEndPos, true);
	TE_SendToAll();
}

void MakeTeslaEffect(const float fPos[3]) 
{
	int iEntity = CreateEntityByName("point_tesla");
	DispatchKeyValue(iEntity, "beamcount_min", "5"); 
	DispatchKeyValue(iEntity, "beamcount_max", "10");
	DispatchKeyValue(iEntity, "lifetime_min", "0.2");
	DispatchKeyValue(iEntity, "lifetime_max", "0.5");
	DispatchKeyValue(iEntity, "m_flRadius", "100.0");
	DispatchKeyValue(iEntity, "m_SoundName", "DoSpark");
	DispatchKeyValue(iEntity, "texture", "sprites/physbeam.vmt");
	DispatchKeyValue(iEntity, "m_Color", "255 255 255");
	DispatchKeyValue(iEntity, "thick_min", "1.0");  
	DispatchKeyValue(iEntity, "thick_max", "10.0");
	DispatchKeyValue(iEntity, "interval_min", "0.1"); 
	DispatchKeyValue(iEntity, "interval_max", "0.2"); 

	DispatchSpawn(iEntity);
	TeleportEntity(iEntity, fPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(iEntity, "TurnOn"); 
	AcceptEntityInput(iEntity, "DoSpark");

	SetVariantString("OnUser1 !self:kill::2.0:-1");
	AcceptEntityInput(iEntity, "AddOutput"); 
	AcceptEntityInput(iEntity, "FireUser1");
}

public void LR_OnMenuCreated(int iClient, int iRank, Menu& hMenu)
{
	if(iRank == g_iEELevel)
	{
		char sText[64];
		SetGlobalTransTarget(iClient);
		if(LR_GetClientRank(iClient) >= g_iEELevel)
		{
			switch(g_iEEButton[iClient])
			{
				case 0: FormatEx(sText, sizeof(sText), "%t", "EE_On");
				case 1: FormatEx(sText, sizeof(sText), "%t", "EE_Off");
			}

			hMenu.AddItem("ElectroEffect", sText);
		}
		else
		{
			FormatEx(sText, sizeof(sText), "%t", "EE_RankClosed", g_iEELevel);
			hMenu.AddItem("ElectroEffect", sText, ITEMDRAW_DISABLED);
		}
	}
}

public void LR_OnMenuItemSelected(int iClient, int iRank, const char[] sInfo)
{
	if(iRank == g_iEELevel)
	{
		if(strcmp(sInfo, "ElectroEffect") == 0)
		{
			switch(g_iEEButton[iClient])
			{
				case 0: g_iEEButton[iClient] = 1;
				case 1: g_iEEButton[iClient] = 0;
			}
			
			LR_MenuInventory(iClient);
		}
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[8];
	GetClientCookie(iClient, g_hElectroEffect, sCookie, sizeof(sCookie));
	g_iEEButton[iClient] = StringToInt(sCookie);
} 

public void OnClientDisconnect(int iClient)
{
	if(AreClientCookiesCached(iClient))
	{
		char sBuffer[8];
		FormatEx(sBuffer, sizeof(sBuffer), "%i", g_iEEButton[iClient]);
		SetClientCookie(iClient, g_hElectroEffect, sBuffer);		
	}
}

public void OnPluginEnd()
{
	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
		{
			OnClientDisconnect(iClient);
		}
	}
}