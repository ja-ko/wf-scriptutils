/*
Copyright (c) 2019, Jannik Kolodziej, All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 3.0 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library.
*/

/*
This file depends on WF scriptutils:
	functioncallcenter.as
*/

/* ============================================================
USE AUTHENTICATION FALLBACK
IF TRUE THIS FILE WILL USE THE ALTERNATIVE
EASIER TO HACK, BUT WORKS WITHOUT AUTHKEY ON SERVER
============================================================ */
const bool log_useAuthFallback = true;


namespace StatisticLog
{

	const uint BUFFERLEN = 2048;
	const String EXTENSION = ".log";

	Log log;

	bool[] clientIsLoggedIn( maxClients );

	void Init()
	{
		log.initialize();

		FunctionCallCenter::RegisterScoreEventListener( HandleScoreEvent );
		FunctionCallCenter::RegisterPlayerRespawnListener( HandlePlayerRespawn );
		FunctionCallCenter::RegisterMatchStateStartedListener( HandleMatchStateStarted );
		FunctionCallCenter::RegisterGametypeShutdownListener( HandleGameShutdown );
		FunctionCallCenter::SetInterval( CheckLoginStatus, 1000 );

		if( ::log_useAuthFallback )
		{
			ClientCvar::Register( "cl_mm_session", "0" );
			ClientCvar::Register( "cl_mm_user", "" );
		}

		for( int i = 0; i < ::maxClients; i++ )
		{
			clientIsLoggedIn[i] = false;
		}
	}

	void HandleScoreEvent( Client @client, String &score_event, String &args )
	{
		if( score_event == "kill" )
		{
			int attacker = ( @client == null ) ? -1 : client.playerNum;
			int target = ( args.getToken(0).len() == 0 || !args.getToken(0).isNumeric() ) ? -1 : args.getToken(0).toInt();

			int mod = ( args.getToken(3).len() == 0 || !args.getToken(3).isNumeric() ) ? -1 : args.getToken(3).toInt();

			if( @::G_GetEntity( target ) != null && @::G_GetEntity( target ).client != null )
				target = ::G_GetEntity( target ).client.playerNum;

			log.logFrag( PlayerMMInfo(attacker), PlayerMMInfo(target), mod );
		}
		else if ( score_event == "award" )
		{
			log.logAward( PlayerMMInfo(client.playerNum), args );
		}
		else if ( score_event == "connect" )
		{
			log.logConnect( PlayerMMInfo(client.playerNum) );
		}
		else if ( score_event == "enterGame" )
		{
			log.logEnterGame( PlayerMMInfo(client.playerNum) );
		}
		else if ( score_event == "disconnect" )
		{
			clientIsLoggedIn[client.playerNum] = false;
			log.logDisconnect( PlayerMMInfo(client.playerNum) );
		}
		else if ( score_event == "pickup" )
		{
			log.logPickup( PlayerMMInfo(client.playerNum), args.getToken( 0 ) );
		}
		else if ( score_event == "userinfochanged" && client.name.removeColorTokens() != args.removeColorTokens() )
		{
			if( client.state() >= ::CS_SPAWNED )
				log.logRename( PlayerMMInfo(client.playerNum), args );
		}
	}

	void HandlePlayerRespawn( Entity @ent, int old_team, int new_team )
	{
		if( new_team != old_team )
			log.logTeamChange( PlayerMMInfo(ent.client.playerNum), old_team, new_team );

		if( old_team != new_team && new_team == ::TEAM_SPECTATOR && ::match.getState() < ::MATCH_STATE_POSTMATCH )
			log.logPlayerStats( PlayerMMInfo(ent.client.playerNum) );
	}

	bool CheckLoginStatus()
	{
		for( int i = 0; i < ::maxClients; i++ )
		{
			if( ( PlayerMMInfo(i).sessionID > 0 ) != clientIsLoggedIn[i] )
			{
				if( clientIsLoggedIn[i] )
					log.logLoggedOut( PlayerMMInfo(i) );
				else
					log.logLoggedIn( PlayerMMInfo(i) );

				clientIsLoggedIn[i] = ( PlayerMMInfo(i).sessionID > 0 );
			}
		}
		return true;
	}

	void HandleMatchStateStarted()
	{
		log.logMatchStateStarted();
		if( ::match.getState() == ::MATCH_STATE_POSTMATCH )
		{
			PlayerMMInfo info(0);
			while (info >= 0)
			{
				log.logPlayerStats(info);
				info++;
			}
		}
	}

	void HandleGameShutdown()
	{
		if( ::match.getState() <= ::MATCH_STATE_PLAYTIME ) // if you shut the gametype down using map, or quit, players won't go spec before d/c, compensate!
		{
			PlayerMMInfo info(0);
			while (info >= 0)
			{
				log.logPlayerStats(info);
				info++;
			}
		}
		log.finalize();
	}
}

class PlayerMMInfo
{
	private int m_playerNum;

	PlayerMMInfo()
	{
		m_playerNum = -1;
	}

	PlayerMMInfo( int input )
	{
		if( input >= 0 && input < maxClients )
			m_playerNum = input;
		else
			m_playerNum = -1;
	}

	bool active()
	{
		if( @G_GetClient( m_playerNum ) == null )
			return false;
		else
			return ( G_GetClient( m_playerNum ).state() >= CS_SPAWNED );
	}

	Client @get_client()
	{
		return G_GetClient( m_playerNum );
	}

	int get_sessionID()
	{
		if( log_useAuthFallback )
		{
			String session = ClientCvar::Get( client, "cl_mm_session" );
			if( session == "null" || session == "0" )
				return -1;
			else
				return session.toInt();
		}
		return ( active() ) ? G_GetClient( m_playerNum ).sessionID : 0;
	}

	String get_loginName()
	{
		if( log_useAuthFallback )
		{
			String name = ClientCvar::Get( client, "cl_mm_user" );
			if( name == "null" )
				return "";
			else
				return name;
		}
		return ( active() ) ? G_GetClient( m_playerNum ).loginName : "";
	}

	String get_name()
	{
		return ( active() ) ? G_GetClient( m_playerNum ).name : "";
	}

	int get_playerNum()
	{
		return ( m_playerNum >= 0 && m_playerNum < maxClients ) ? m_playerNum : -1;
	}

	Stats @get_stats()
	{
		return ( active() ) ? @G_GetClient( m_playerNum ).stats : null;
	}

	bool opEquals( PlayerMMInfo input )
	{
		return (m_playerNum == input.playerNum);
	}

	PlayerMMInfo &opAssign( PlayerMMInfo input )
	{
		m_playerNum = ( input.playerNum >= 0 && input.playerNum < maxClients ) ? input.playerNum : -1;
		return this;
	}

	PlayerMMInfo &opAssign( int input )
	{
		m_playerNum = ( input >= 0 && input < maxClients ) ? input : -1;
		return this;
	}

	bool opEquals( int input )
	{
		return (m_playerNum == input);
	}

	PlayerMMInfo &opAddAssign( int input )
	{
		m_playerNum = ( input + m_playerNum >= 0 && input + m_playerNum < maxClients ) ? m_playerNum + input : -1;
		return this;
	}

	PlayerMMInfo &opSubAssign( int input )
	{
		m_playerNum = ( input - m_playerNum >= 0 && input - m_playerNum < maxClients ) ? m_playerNum - input : -1;
		return this;
	}

	int opCmp( int value )
	{
		return m_playerNum - value;
	}

	int opCmp( PlayerMMInfo value )
	{
		return m_playerNum - value.playerNum;
	}

	PlayerMMInfo &opPostInc()
	{
		if( m_playerNum >= maxClients - 1 )
			m_playerNum = -1;
		else
			m_playerNum++;

		return this;
	}

	PlayerMMInfo &opPostDec()
	{
		if( m_playerNum <= 0 )
			m_playerNum = -1;
		else
			m_playerNum--;

		return this;
	}

};

class Log
{
	String buffer;
	String filename;

	bool active;

	Log()
	{
		active = false;
		buffer = "";
		filename = "";
	}

	void initialize()
	{
		String file;
		String dir;
		String header;

		Cvar mapname( "mapname", "", CVAR_ARCHIVE );
		Cvar servername( "sv_hostname", "", CVAR_ARCHIVE );
		Cvar serverport( "sv_port", "", CVAR_ARCHIVE );
		Cvar ip( "sv_ip", "", CVAR_ARCHIVE );
		Cvar port( "sv_port", "", CVAR_ARCHIVE );
		Cvar insta( "g_instagib", "", CVAR_ARCHIVE );
		Cvar fsgame( "fs_game", "", CVAR_ARCHIVE );
		Cvar mm( "sv_mm_enable", "", CVAR_ARCHIVE );
		Cvar mmonly( "sv_mm_loginonly", "", CVAR_ARCHIVE );
		Cvar gversion( "version", "", CVAR_ARCHIVE );

		Time now = Time( localTime );

		dir = "logs_" + gametype.title;
		file = mapname.string + "_" + ( 1900 + now.year ) + "-" + StringUtils::FormatInt( 1 + now.mon, "0", 2 ) + "-" + StringUtils::FormatInt( now.mday, "0", 2 ) + "_" + StringUtils::FormatInt( now.hour, "0", 2 ) + "-" + StringUtils::FormatInt( now.min, "0", 2 ) + "-" + StringUtils::FormatInt( now.sec, "0", 2 ) + StatisticLog::EXTENSION;

		filename = dir + "/" + file;

		header = "<" + gametype.name + " version=\"" + gametype.version + "\">\n";
		header += "\t<header ";
		header += "servername=\"" + servername.string + "\" ";
		header += "sv_ip=\"" + ip.string + "\" ";
		header += "serverport=\"" + serverport.integer + "\" ";
		header += "maxclients=\"" + maxClients + "\" ";
		header += "gametype=\"" + gametype.name + "\" ";
		header += "gtversion=\"" + gametype.version + "\" ";
		header += "gtauthor=\"" + gametype.author + "\" ";
		header += "localtime=\"" + localTime + "\" ";
		header += "leveltime=\"" + levelTime + "\" ";
		header += "mod=\"" + fsgame.string + "\" ";
		header += "mapname=\"" + mapname.string + "\" ";
		header += "instagib=\"" + (insta.boolean ? "true" : "false") + "\" ";
		header += "mm=\"" + (mm.boolean ? "true" : "false") + "\" ";
		header += "mmonly=\"" + (mmonly.boolean ? "true" : "false") + "\" ";
		header += "gameversion=\"" + gversion.string + "\" ";
		header += "/>\n";

		G_WriteFile( filename, header );

		active = true;
	}

	void checkBuffer()
	{
		if( buffer.len() > StatisticLog::BUFFERLEN )
			flushBuffer();
	}

	void flushBuffer()
	{
		G_AppendToFile(filename, buffer);
		buffer = "";
	}

	void finalize()
	{
		if( !active )
			return;

		flushBuffer();
		G_AppendToFile( filename, "</" + gametype.name + ">" );
		active = false;
	}

	void logFrag( PlayerMMInfo attacker, PlayerMMInfo target, int mod )
	{
		if( !active )
			return;

		if( match.getState() == MATCH_STATE_WARMUP )
			return;

		buffer += "\t<frag attacker=\"" + attacker.name  + "\" attackerwmmname=\"" + attacker.loginName + "\" attackersession=\"" + attacker.sessionID + "\" target=\"" + target.name  + "\" targetwmmname=\"" + target.loginName + "\" targetsession=\"" + target.sessionID + "\" mod=\"" + mod + "\" leveltimestamp=\"" + levelTime + "\" />\n";
		checkBuffer();
	}

	void logPickup( PlayerMMInfo client, String classname )
	{
		if( !active )
			return;

		if( match.getState() == MATCH_STATE_WARMUP )
			return;

		if( client.playerNum < 0 )
			return;

		buffer += "\t<pickup client=\"" + client.name + "\" wmmname=\"" + client.loginName + "\" sessionid=\"" + client.sessionID + "\" playernum=\"" + client.playerNum + "\" item=\"" + classname + "\" leveltimestamp=\"" + levelTime + "\" />\n";
		checkBuffer();
	}

	void logEnterGame( PlayerMMInfo @client )
	{
		if( !active )
			return;

		if( client.playerNum < 0 )
			return;

		buffer += "\t<entergame client=\"" + client.name + "\" wmmname=\"" + client.loginName + "\" sessionid=\"" + client.sessionID + "\" playernum=\"" + client.playerNum + "\" leveltimestamp=\"" + levelTime + "\" />\n";
		checkBuffer();
	}

	void logConnect( PlayerMMInfo client )
	{
		if( !active )
			return;

		if( client.playerNum < 0 )
			return;

		String ip;
		ip = client.client.getUserInfoKey( "ip" );

		buffer += "\t<connect client=\"" + client.name + "\" ip=\"" + ip + "\" playernum=\"" + client.playerNum + "\" leveltimestamp=\"" + levelTime + "\" />\n";
		checkBuffer();
	}

	void logAward( PlayerMMInfo client, String award )
	{
		if( !active )
			return;

		if( client.playerNum < 0 )
			return;

		if( award.len() == 0 )
			return;

		if( match.getState() == MATCH_STATE_WARMUP )
			return;

		buffer += "\t<award client=\"" + client.name + "\" award=\"" + award + "\" playernum=\"" + client.playerNum + "\" wmmname=\"" + client.loginName + "\" sessionid=\"" + client.sessionID + "\" leveltimestamp=\"" + levelTime + "\" />\n";
		checkBuffer();
	}

	void logDisconnect( PlayerMMInfo client )
	{
		if( !active )
			return;

		if( client.playerNum < 0 )
			return;

		buffer += "\t<disconnect client=\"" + client.name + "\" playernum=\"" + client.playerNum + "\" wmmname=\"" + client.loginName + "\" sessionid=\"" + client.sessionID + "\" leveltimestamp=\"" + levelTime + "\" />\n";
		checkBuffer();
	}

	void logTeamChange( PlayerMMInfo client, int old_team, int new_team )
	{
		if( !active )
			return;

		if( client.playerNum < 0 )
			return;

		buffer += "\t<teamchange client=\"" + client.name + "\" playernum=\"" + client.playerNum + "\" wmmname=\"" + client.loginName + "\" sessionid=\"" + client.sessionID + "\" old_team=\"" + old_team + "\" new_team=\"" + new_team + "\" leveltimestamp=\"" + levelTime + "\" />\n";
		checkBuffer();
	}

	void logMatchStateStarted()
	{
		if( !active )
			return;

		buffer += "\t<matchstatestarted new_state=\"" + match.getState() + "\" leveltimestamp=\"" + levelTime + "\" />\n";
		checkBuffer();
	}

	void logCustomMessage( String message )
	{
		if( !active )
			return;

		buffer += "\t<custommessage leveltimestamp=\"" + levelTime + "\">\n";
		buffer += "\t\t" + message + "\n";
		buffer += "\t</custommessage>";

		checkBuffer();
	}

	void logRename( PlayerMMInfo client, String oldname )
	{
		if( !active )
			return;

		if( client.playerNum < 0 )
			return;

		buffer+= "\t<rename client=\"" + client.name + "\" playernum=\"" + client.playerNum + "\" wmmname=\"" + client.loginName + "\" sessionid=\"" + client.sessionID + "\" oldname=\"" + oldname + "\" leveltimestamp=\"" + levelTime + "\" />\n";
		checkBuffer();
	}

	void logLoggedIn( PlayerMMInfo client )
	{
		if( !active )
			return;

		if( client.playerNum < 0 )
			return;

		buffer += "\t<login client=\"" + client.name + "\" playernum=\"" + client.playerNum + "\" wmmname=\"" + client.loginName + "\" sessionid=\"" + client.sessionID + "\" leveltimestamp=\"" + levelTime + "\" />\n";
		checkBuffer();
	}

	void logLoggedOut( PlayerMMInfo client )
	{
		if( !active )
			return;

		if( client.playerNum < 0 )
			return;

		buffer += "\t<logout client=\"" + client.name + "\" playernum=\"" + client.playerNum + "\" leveltimestamp=\"" + levelTime + "\" />\n";
		checkBuffer();
	}

	void logPlayerStats( PlayerMMInfo client )
	{
		// we don't want to log player stats for now
		/*if( !active )
			return;

		if( client.playerNum < 0 )
			return;

		if( !client.active() )
			return;

		if( match.getState() == MATCH_STATE_WARMUP )
			return;

		buffer += "\t<stats client=\"" + client.name + "\" playernum=\"" + client.playerNum + "\" wmmname=\"" + client.loginName + "\" sessionid=\"" + client.sessionID + "\" leveltimestamp=\"" + levelTime + "\">\n";
		buffer += "\t\t<frags>" + client.stats.frags + "</frags>\n";
		buffer += "\t\t<teamfrags>" + client.stats.teamFrags + "</teamfrags>\n";
		buffer += "\t\t<suicides>" + client.stats.suicides + "</suicides>\n";
		buffer += "\t\t<deaths>" + client.stats.deaths + "</deaths>\n";
		buffer += "\t\t<score>" + client.stats.score + "</score>\n";
		buffer += "\t\t<healthtaken>" + client.stats.healthTaken + "</healthtaken>\n";
		buffer += "\t\t<armortaken>" + client.stats.armorTaken + "</armortaken>\n";
		buffer += "\t\t<totaldamagegiven>" + client.stats.totalDamageGiven + "</totaldamagegiven>\n";
		buffer += "\t\t<totaldamagereceived>" + client.stats.totalDamageReceived + "</totaldamagereceived>\n";
		buffer += "\t\t<totalteamdamagegiven>" + client.stats.totalTeamDamageGiven + "</totalteamdamagegiven>\n";
		buffer += "\t\t<totalteamdamagereceived>" + client.stats.totalTeamDamageReceived + "</totalteamdamagereceived>\n";
		buffer += "\t\t<accuracy ammo=\"" + AMMO_BOLTS + "\">" + client.stats.accuracyHits( AMMO_BOLTS ) + "/" + client.stats.accuracyShots( AMMO_BOLTS ) + "</accuracy>\n";
		buffer += "\t\t<accuracy ammo=\"" + AMMO_BULLETS + "\">" + client.stats.accuracyHits( AMMO_BULLETS ) + "/" + client.stats.accuracyShots( AMMO_BULLETS ) + "</accuracy>\n";
		buffer += "\t\t<accuracy ammo=\"" + AMMO_GRENADES + "\">" + client.stats.accuracyHits( AMMO_GRENADES ) + "/" + client.stats.accuracyShots( AMMO_GRENADES ) + "</accuracy>\n";
		buffer += "\t\t<accuracy ammo=\"" + AMMO_GUNBLADE + "\">" + client.stats.accuracyHits( AMMO_GUNBLADE ) + "/" + client.stats.accuracyShots( AMMO_GUNBLADE ) + "</accuracy>\n";
		buffer += "\t\t<accuracy ammo=\"" + AMMO_INSTAS + "\">" + client.stats.accuracyHits( AMMO_INSTAS ) + "/" + client.stats.accuracyShots( AMMO_INSTAS ) + "</accuracy>\n";
		buffer += "\t\t<accuracy ammo=\"" + AMMO_LASERS + "\">" + client.stats.accuracyHits( AMMO_LASERS ) + "/" + client.stats.accuracyShots( AMMO_LASERS ) + "</accuracy>\n";
		buffer += "\t\t<accuracy ammo=\"" + AMMO_PLASMA + "\">" + client.stats.accuracyHits( AMMO_PLASMA ) + "/" + client.stats.accuracyShots( AMMO_PLASMA ) + "</accuracy>\n";
		buffer += "\t\t<accuracy ammo=\"" + AMMO_ROCKETS + "\">" + client.stats.accuracyHits( AMMO_ROCKETS ) + "/" + client.stats.accuracyShots( AMMO_ROCKETS ) + "</accuracy>\n";
		buffer += "\t\t<accuracy ammo=\"" + AMMO_SHELLS + "\">" + client.stats.accuracyHits( AMMO_SHELLS ) + "/" + client.stats.accuracyShots( AMMO_SHELLS ) + "</accuracy>\n";
		buffer += "\t</stats>\n";
		checkBuffer();*/
	}
};
