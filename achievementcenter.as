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
	scoreboard.as
	stringutils.as
*/

/* ============================================================
WARNING!
THIS FILE CONTAINS LOCAL DEBUG LINES
============================================================ */
const bool acenter_debugmode = false;

/* ============================================================
USE AUTHENTICATION FALLBACK
IF TRUE THIS FILE WILL USE THE ALTERNATIVE
EASIER TO HACK, BUT WORKS WITHOUT AUTHKEY ON SERVER
============================================================ */
const bool acenter_useAuthFallback = true;

namespace AchievementCenter
{
	array<AchievementScoreboard@> scoreboardAchievements;
	array<AchievementSkin@> skinAchievements;
	array<AchievementModel@> modelAchievements;
	array<AchievementStandartStreak@> standartAchievementsStreak;
	array<AchievementMeta@> metaAchievements;

	PlayerAchievementCenter[] ac_playerCenter( ::maxClients );

	void Init()
	{
		ScoreBoardHelper::RegisterEntryModifier( _scoreboardModifier );

		FunctionCallCenter::RegisterPlayerRespawnListener( _playerRespawn );
		FunctionCallCenter::RegisterScoreEventListener( _enterGameEvent );
		FunctionCallCenter::RegisterGametypeShutdownListener( _shutdown );

		FunctionCallCenter::SetInterval( _think1s, 1000 );

		ClientCvar::Register( "cg_ka_modelext", "" );

		if( ::acenter_useAuthFallback )
		{
			ClientCvar::Register( "cl_mm_session", "0" );
			ClientCvar::Register( "cl_mm_user", "" );
		}

		for( int i = 0; i < ::maxClients; i++ )
		{
			ac_playerCenter[i].init( ::G_GetClient( i ) );
		}
	}

	void RegisterAchievement( AchievementScoreboard @achievement )
	{
		scoreboardAchievements.insertLast( achievement );
	}

	/*void RegisterAchievement( AchievementSkin @achievement )
	{
		skinAchievements.insertLast( achievement );
	}*/

	void RegisterAchievement( AchievementModel @achievement )
	{
		modelAchievements.insertLast( achievement );
	}

	void RegisterAchievement( AchievementStandart @achievement )
	{
		AchievementStandartStreak achievementStreak;
		achievementStreak.streak.insertLast( achievement );
		standartAchievementsStreak.insertLast( achievementStreak );
	}

	void RegisterAchievement( AchievementStandart @first, AchievementStandart @second )
	{
		AchievementStandartStreak achievementStreak;
		achievementStreak.streak.insertLast( first );
		achievementStreak.streak.insertLast( second );
		standartAchievementsStreak.insertLast( achievementStreak );
	}

	void RegisterAchievement( AchievementStandart @first, AchievementStandart @second, AchievementStandart @third )
	{
		AchievementStandartStreak achievementStreak;
		achievementStreak.streak.insertLast( first );
		achievementStreak.streak.insertLast( second );
		achievementStreak.streak.insertLast( third );
		standartAchievementsStreak.insertLast( achievementStreak );
	}

	void RegisterAchievement( AchievementStandart @first, AchievementStandart @second, AchievementStandart @third, AchievementStandart @fourth )
	{
		AchievementStandartStreak achievementStreak;
		achievementStreak.streak.insertLast( first );
		achievementStreak.streak.insertLast( second );
		achievementStreak.streak.insertLast( third );
		achievementStreak.streak.insertLast( fourth );
		standartAchievementsStreak.insertLast( achievementStreak );
	}

	void RegisterAchievement( AchievementStandartStreak @achievementStreak )
	{
		standartAchievementsStreak.insertLast( achievementStreak );
	}

	void RegisterAchievement( AchievementMeta @achievementMeta )
	{
		metaAchievements.insertLast( achievementMeta );
	}

	bool IsActive( Client @client )
	{
		if( @client == null || client.state() < ::CS_SPAWNED )
			return false;
		PlayerAchievementCenter @acenter = @ac_playerCenter[client.playerNum];
		return acenter.loggedIn;
	}

	String LoginName( Client @client )
	{
		if( @client == null || client.state() < ::CS_SPAWNED )
			return "";
		PlayerAchievementCenter @acenter = @ac_playerCenter[client.playerNum];
		return acenter.loginName;
	}

	uint AchievementPoints( Client @client )
	{
		if( @client == null || client.state() < ::CS_SPAWNED )
			return 0;
		PlayerAchievementCenter @acenter = @ac_playerCenter[client.playerNum];
		if( !acenter.isActive )
			return 0;
		return acenter.achievementPoints;
	}

	String StandartAchievementsInterfaceString( Client @client, uint start, uint count )
	{
		if( @client == null || client.state() < ::CS_SPAWNED )
			return "";
		PlayerAchievementCenter @acenter = @ac_playerCenter[client.playerNum];
		String ret = "";

		for( uint i = start; ( i < start + count ) && ( i < acenter.standartAchievementsStreak.length ); i++ )
		{
			ret += acenter.standartAchievementsStreak[i].streak[0].ui_identifier;
			if( acenter.standartAchievementsStreak[i].streak[acenter.standartAchievementsStreak[i].streak.length-1].reached )
			{
				if( acenter.standartAchievementsStreak[i].streak[acenter.standartAchievementsStreak[i].streak.length-1].progress < 0.0f )
					ret += acenter.standartAchievementsStreak[i].streak.length + ".--";
				else
					ret += acenter.standartAchievementsStreak[i].streak.length + ".00";
			}
			else
			{
				for( uint j = 0; j < acenter.standartAchievementsStreak[i].streak.length; j++ )
				{
					if( acenter.standartAchievementsStreak[i].streak[j].reached )
						continue;
					if( acenter.standartAchievementsStreak[i].streak[j].progress < 0.0f )
					{
						ret += j + ".--";
					}
					else
					{
						float progress = acenter.standartAchievementsStreak[i].streak[j].progress + float(j);
						ret += StringUtils::FormatFloat( progress, '0', 4, 2);
					}
					break;
				}
			}
		}

		return ret;
	}

	String AvailableModels( Client @client )
	{
		if( @client == null || client.state() < ::CS_SPAWNED )
			return "";
		PlayerAchievementCenter @acenter = @ac_playerCenter[client.playerNum];
		String ret = "";

		for( uint i = 0; i < acenter.modelAchievements.length; i++ )
		{
			if( @acenter.modelAchievements[i] == null || !acenter.modelAchievements[i].available )
				continue;
			ret += acenter.modelAchievements[i].modelName + " ";
		}

		ret = ret.substr( 0, ret.len() - 1 ); // remove last whitespace
		return ret;
	}

	String AllModels()
	{
		String ret = "";
		for( uint i = 0; i < modelAchievements.length; i++ )
		{
			if( @modelAchievements[i] != null )
				ret += modelAchievements[i].copy().modelName + " ";
		}
		ret = ret.substr( 0, ret.len() - 1 );
		return ret;
	}

	String _scoreboardModifier( Entity @ent, String entry )
	{
		array<int> sbModifyIndices;
		String layout = ScoreBoardHelper::ScoreboardLayout;
		for( int i = 0; layout.getToken( i ) != ""; i++ )
		{
			if( layout.getToken( i ) == "%s" )
			{
				sbModifyIndices.insertLast( i / 2 );
			}
		}

		for( int i = 0; i < ::maxClients; i++ )
		{
			if( @ac_playerCenter[i].get_entity() == @ent ) // standart getter doesn't support objecthandle in our angelscript version
				return ac_playerCenter[i].addScoreboardColorTokens( entry, sbModifyIndices );
		}
		return entry;
	}

	void _enterGameEvent( Client @client, String &score_event, String &args )
	{
		if( score_event != "enterGame" && score_event != "disconnect" )
			return;

		if( @client == null )
			return;

		if( score_event == "enterGame" )
			ac_playerCenter[client.playerNum].reset();
		else if( score_event == "disconnect" )
			ac_playerCenter[client.playerNum].shutdown();
	}

	void _playerRespawn( Entity @ent, int old_team, int new_team )
	{
		if( @ent == null || @ent.client == null || ent.client.state() < ::CS_SPAWNED || ent.team == ::TEAM_SPECTATOR || new_team != old_team )
			return;
		ac_playerCenter[ent.client.playerNum].addModelExtension();
		ac_playerCenter[ent.client.playerNum].setSkinID();
	}

	bool _think1s()
	{
		for( int i = 0; i < ::maxClients; i++ )
		{
			ac_playerCenter[i].think1s();
		}
		return true;
	}

	void _shutdown()
	{
		for( int i = 0; i < ::maxClients; i++ )
		{
			ac_playerCenter[i].shutdown();
		}
	}
}

// mixin classes are not supported in our anglescript version
/*mixin class AchievementMixin
{
	String name;
	bool active;
	bool available;

	Client @client;

	void init( Client @client ) {}
	void shutdown() {}
}*/

class AchievementScoreboard // : AchievementMixin
{
	AchievementScoreboard() { rank = "something"; available = false; }

	AchievementScoreboard @copy() { return null; }

	bool available;
	String identifier;

	String rank;

	Client @client;

	void init( Client @inClient, String serializedData ) { @client = @inClient; }
	String shutdown() { return ""; }

	void achievementPointsChanged( uint newPoints ) {}

	String color;

	bool opEquals( AchievementScoreboard @input )
	{
        if( @input == null )
            return false;

        return input is this;
	}
}

// We can't force skins, because we won't force player models.
// This block (and related parts) can be removed, but it won't hurt if it stays
class AchievementSkin // : AchievementMixin
{
	AchievementSkin() {}

	AchievementSkin @copy() { return null; }

	bool available;
	String identifier;

	Client @client;

	void init( Client @inClient, String serializedData ) { @client = @inClient; }
	String shutdown() { return ""; }

	void achievementPointsChanged( uint newPoints ) {}

	int skinID;

	bool opEquals( AchievementSkin @input )
	{
        if( @input == null )
            return false;

        return input is this;
	}
}

class AchievementModel // : AchievementMixin
{
	AchievementModel() { available = false; }

	AchievementModel @copy() { return null; }

	bool available;
	String identifier;

	Client @client;

	void init( Client @inClient, String serializedData ) { @client = @inClient; }
	String shutdown() { return ""; }

	void achievementPointsChanged( uint newPoints ) {}

	int modelID;
	String modelPath;
	String modelName;

	bool opEquals( AchievementModel @input )
	{
        if( @input == null )
            return false;

        return input is this;
	}
}

class AchievementStandart
{
	AchievementStandart() { reached = false; }

	AchievementStandart @copy() { return null; }

	bool reached;
	String identifier;
	String ui_identifier;

	uint points;

	uint checkReached() { return 0; }

	float get_progress() { return -1.0f; }

	Client @client;

	void init( Client @inClient, String serializedData ) { @client = @inClient; }
	String shutdown() { return ""; }

	void achievementPointsChanged( uint newPoints ) {}

    bool opEquals( AchievementStandart @input )
	{
        if( @input == null )
            return false;

        return input is this;
	}

    bool opEquals( AchievementStandart input )
	{
        return input.client is client && input.identifier == identifier;
	}
}

class AchievementStandartStreak
{
	array<AchievementStandart@> streak;
}

// meta achievements are achievements, that don't have a direct influence on anything
class AchievementMeta
{
	AchievementMeta() { enabled = false; identifier = ""; }

	AchievementMeta @copy() { return null; }

	Client @client;

	bool enabled;
	String identifier;

	void init( Client @inClient, String serializedData ) { @client = @inClient; }
	String shutdown() { return ""; }
}

class PlayerAchievementCenter
{
	Client @m_client;

	bool isActive;

	String m_loginName;

	array<AchievementScoreboard@> scoreboardAchievements;
	array<AchievementSkin@> skinAchievements;
	array<AchievementModel@> modelAchievements;
	//array<AchievementStandart@> standartAchievements;
	array<AchievementStandartStreak@> standartAchievementsStreak;
	array<AchievementMeta@> metaAchievements;

	uint achievementPoints;

	PlayerAchievementCenter()
	{
		isActive = false;
		achievementPoints = 0;
		m_loginName = "";
	}

	void init( Client @inclient )
	{
		if( @inclient == null )
			return;

		@m_client = @inclient;
		m_loginName = "";
		achievementPoints = 0;

		if( inclient.state() < CS_SPAWNED )
			return;

		// ========================================================
		// LOCAL DEBUG BLOCK
		if( !acenter_debugmode )
		{
			if( !loggedIn )
				return;
		}

		isActive = true;
		m_loginName = loginName;

		String dataPath = StringUtils::RemoveInvalidPathChars( "achievements/" + loginName + ".ac" );

		// ========================================================
		// LOCAL DEBUG BLOCK
		if( acenter_debugmode )
		{
			if( client.name.removeColorTokens().tolower() == "drahti" )
				dataPath = StringUtils::RemoveInvalidPathChars( "achievements/" + "drahti" + ".ac" );
			if( client.name.removeColorTokens().tolower() == "jonsen" )
				dataPath = StringUtils::RemoveInvalidPathChars( "achievements/" + "jonsen" + ".ac" );
			if( client.name.removeColorTokens().tolower() == "dastier" )
				dataPath = StringUtils::RemoveInvalidPathChars( "achievements/" + "dastier" + ".ac" );
			if( client.name.removeColorTokens().tolower() == "kalle" )
				dataPath = StringUtils::RemoveInvalidPathChars( "achievements/" + "kalle" + ".ac" );
			if( client.name.removeColorTokens().tolower() == "kenny" )
				dataPath = StringUtils::RemoveInvalidPathChars( "achievements/" + "kenny" + ".ac" );
		}

		Dictionary @dict = @Serialization::DeserializeStringDictionary( dataPath );

		for( uint i = 0; i < AchievementCenter::scoreboardAchievements.length; i++ )
		{
			AchievementScoreboard @ascore = @AchievementCenter::scoreboardAchievements[i].copy();
			if( @ascore != null && ascore.identifier != "" )
			{
				String @serializedData = null;
				if( @dict != null )
					dict.get( ascore.identifier, @serializedData );
				if( @serializedData == null )
					@serializedData = "" + ""; // weird as-bug

				ascore.init( client, serializedData );
				scoreboardAchievements.insertLast( ascore );
			}
		}

		for( uint i = 0; i < AchievementCenter::standartAchievementsStreak.length; i++ )
		{
			if( @AchievementCenter::standartAchievementsStreak[i] == null )
				continue;

			AchievementStandartStreak achievementStreak;
			for( uint j = 0; j < AchievementCenter::standartAchievementsStreak[i].streak.length; j++ )
			{
				if( @AchievementCenter::standartAchievementsStreak[i].streak[j] == null )
					continue;
				AchievementStandart @astandart = @AchievementCenter::standartAchievementsStreak[i].streak[j].copy();
				if( @astandart != null && astandart.identifier != "" )
				{
					String @serializedData = null;
					if( @dict != null )
						dict.get( astandart.identifier, @serializedData );
					if( @serializedData == null )
						@serializedData = "" + ""; // weird as-bug

					astandart.init( client, serializedData );
					if( astandart.reached )
						achievementPoints += astandart.points;
					achievementStreak.streak.insertLast( astandart );
				}
			}
			standartAchievementsStreak.insertLast( achievementStreak );
		}

		for( uint i = 0; i < AchievementCenter::skinAchievements.length; i++ )
		{
			AchievementSkin @askin = @AchievementCenter::skinAchievements[i].copy();
			if( @askin != null && askin.identifier != "" )
			{
				String @serializedData = null;
				if( @dict != null )
					dict.get( askin.identifier, @serializedData );
				if( @serializedData == null )
					@serializedData = "" + ""; // weird as-bug

				askin.init( client, serializedData );
				skinAchievements.insertLast( askin );
			}
		}

		for( uint i = 0; i < AchievementCenter::modelAchievements.length; i++ )
		{
			AchievementModel @amodel = @AchievementCenter::modelAchievements[i].copy();
			if( @amodel != null && amodel.identifier != "" )
			{
				String @serializedData = null;
				if( @dict != null )
					dict.get( amodel.identifier, @serializedData );
				if( @serializedData == null )
					@serializedData = "" + ""; // weird as-bug

				amodel.init( client, serializedData );
				amodel.achievementPointsChanged( achievementPoints );
				modelAchievements.insertLast( amodel );
			}
		}

		for( uint i = 0; i < AchievementCenter::metaAchievements.length; i++ )
		{
			AchievementMeta @ameta = @AchievementCenter::metaAchievements[i].copy();
			if( @ameta != null && ameta.identifier != "" )
			{
				String @serializedData = null;
				if( @dict != null )
					dict.get( ameta.identifier, @serializedData );
				if( @serializedData == null )
					@serializedData = "" + ""; // weird as-bug

				ameta.init( client, serializedData );
				metaAchievements.insertLast( ameta );
			}
		}
	}

	void shutdown()
	{
		if( !isActive )
			return;

		isActive = false;

		Dictionary dict();

		for( uint i = 0; i < scoreboardAchievements.length; i++ )
		{
			if( @scoreboardAchievements[i] == null )
				continue;
			dict.set( scoreboardAchievements[i].identifier, scoreboardAchievements[i].shutdown() );
		}
		while( scoreboardAchievements.length > 0 )
			scoreboardAchievements.pop_back();

		for( uint i = 0; i < skinAchievements.length; i++ )
		{
			if( @skinAchievements[i] == null )
				continue;
			dict.set( skinAchievements[i].identifier, skinAchievements[i].shutdown() );
		}
		while( skinAchievements.length > 0 )
			skinAchievements.pop_back();

		for( uint i = 0; i < modelAchievements.length; i++ )
		{
			if( @modelAchievements[i] == null )
				continue;
			dict.set( modelAchievements[i].identifier, modelAchievements[i].shutdown() );
		}
		while( modelAchievements.length > 0 )
			modelAchievements.pop_back();

		/*for( uint i = 0; i < standartAchievements.length; i++ )
		{
			if( @standartAchievements[i] == null )
				continue;
			dict.set( standartAchievements[i].identifier, standartAchievements[i].shutdown() );
		}
		while( standartAchievements.length > 0 )
			standartAchievements.pop_back();*/

		for( uint i = 0; i < standartAchievementsStreak.length; i++ )
		{
			if( @standartAchievementsStreak[i] == null )
				continue;
			for( uint j = 0; j < standartAchievementsStreak[i].streak.length; j++ )
			{
				if( @standartAchievementsStreak[i].streak[j] == null )
					continue;
				dict.set( standartAchievementsStreak[i].streak[j].identifier, standartAchievementsStreak[i].streak[j].shutdown() );
			}
		}
		while( standartAchievementsStreak.length > 0 )
			standartAchievementsStreak.pop_back();

		for( uint i = 0; i < metaAchievements.length; i++ )
		{
			if( @metaAchievements[i] == null )
				continue;
			dict.set( metaAchievements[i].identifier, metaAchievements[i].shutdown() );
		}
		while( metaAchievements.length > 0 )
			metaAchievements.pop_back();

		String availablePath = StringUtils::RemoveInvalidPathChars( "achievements/" + loginName + ".ac" );


		// ========================================================
		// LOCAL DEBUG BLOCK
		if( acenter_debugmode )
		{
			if( client.name.removeColorTokens().tolower() == "drahti" )
				availablePath = StringUtils::RemoveInvalidPathChars( "achievements/" + "drahti" + ".ac" );
			if( client.name.removeColorTokens().tolower() == "jonsen" )
				availablePath = StringUtils::RemoveInvalidPathChars( "achievements/" + "jonsen" + ".ac" );
			if( client.name.removeColorTokens().tolower() == "dastier" )
				availablePath = StringUtils::RemoveInvalidPathChars( "achievements/" + "dastier" + ".ac" );
			if( client.name.removeColorTokens().tolower() == "kalle" )
				availablePath = StringUtils::RemoveInvalidPathChars( "achievements/" + "kalle" + ".ac" );
			if( client.name.removeColorTokens().tolower() == "kenny" )
				availablePath = StringUtils::RemoveInvalidPathChars( "achievements/" + "kenny" + ".ac" );
		}

		Serialization::SerializeStringDictionary( dict, availablePath );
	}

	void reset()
	{
		if( isActive )
			shutdown();

		init( client );
	}

	void think1s()
	{
		checkLogin();

		if( !isActive ) // checkLogin could have disabled this
			return;

		uint oldPoints = achievementPoints;

		/*for( uint i = 0; i < standartAchievements.length; i++ )
		{
			if( @standartAchievements[i] == null )
				continue;
			if( !standartAchievements[i].reached )
				achievementPoints += standartAchievements[i].checkReached();
		}*/
		for( uint i = 0; i < standartAchievementsStreak.length; i++ )
		{
			if( @standartAchievementsStreak[i] == null )
				continue;
			for( uint j = 0; j < standartAchievementsStreak[i].streak.length; j++ )
			{
				if( @standartAchievementsStreak[i].streak[j] == null )
					continue;
				if( !standartAchievementsStreak[i].streak[j].reached )
				{
					achievementPoints += standartAchievementsStreak[i].streak[j].checkReached();
					break;
				}
			}
		}

		if( oldPoints != achievementPoints )
		{
			for( uint i = 0; i < scoreboardAchievements.length; i++ )
			{
				if( @scoreboardAchievements[i] != null && !scoreboardAchievements[i].available )
					scoreboardAchievements[i].achievementPointsChanged( achievementPoints );
			}

			for( uint i = 0; i < skinAchievements.length; i++ )
			{
				if( @skinAchievements[i] != null && !skinAchievements[i].available )
					skinAchievements[i].achievementPointsChanged( achievementPoints );
			}

			for( uint i = 0; i < modelAchievements.length; i++ )
			{
				if( @modelAchievements[i] != null && !modelAchievements[i].available )
					modelAchievements[i].achievementPointsChanged( achievementPoints );
			}
		}
	}

	void checkLogin()
	{
		if( isActive != loggedIn )
			reset();
	}

	bool get_loggedIn()
	{
		if( acenter_useAuthFallback )
		{
			String session = ClientCvar::Get( client, "cl_mm_session" );
			if( !session.isNumerical() )
				return false;
			int sessionID = session.toInt();
			return ( sessionID > 0 );
		}
		else
			return ( client.sessionID > 0 );
	}

	String get_loginName()
	{
		if( m_loginName != "" )
			return m_loginName;

		if( !loggedIn )
			return "invalid";
		if( acenter_useAuthFallback )
		{
			String user = ClientCvar::Get( client, "cl_mm_user" );
			m_loginName = user;
			return user;
		}
		else
		{
			m_loginName = client.loginName;
			return client.loginName;
		}
	}


	String addScoreboardColorTokens( String input, array<int> sbModifyIndices )
	{
		if( !isActive )
			return StringUtils::Replace( input, "%rank%", "---" );

		String ret = "";
		String activeColorToken;
		for( uint i = 0; i < scoreboardAchievements.length; i++ )
		{
			if( @scoreboardAchievements[i] == null )
				continue;
			if( scoreboardAchievements[i].available )
			{
				activeColorToken = scoreboardAchievements[i].color;
				input = StringUtils::Replace( input, "%rank%", scoreboardAchievements[i].rank );
				break;
			}
		}

		if( activeColorToken.len() == 0 )
			return StringUtils::Replace( input, "%rank%", "---" );

		for( uint i = 0; input.getToken( i ) != ""; i++ )
		{
			int arrIndex = sbModifyIndices.find( i - 1 );
			if(  arrIndex != -1 )
			{
				ret += activeColorToken;
			}
			ret += input.getToken( i );
			if( arrIndex != -1 )
				ret += S_COLOR_WHITE;
			ret += " ";
		}
		return ret;
	}

	void addModelExtension()
	{
		if( !isActive )
			return;

		if( @m_client == null || client.state() < CS_SPAWNED || client.getEnt().team == TEAM_SPECTATOR )
			return;

		String activeModel = ClientCvar::Get( client, "cg_ka_modelext" );
		if( activeModel == "null" )
			return;

		for( uint i = 0; i < modelAchievements.length; i++ )
		{
			if( @modelAchievements[i] == null )
				continue;
			if( modelAchievements[i].modelName == activeModel )
			{
				if( !modelAchievements[i].available )
				{
					ClientCvar::Set( client, "cg_ka_modelext", "" );
					return;
				}

				client.getEnt().modelindex2 = modelAchievements[i].modelID;
				break;
			}
		}
	}

	void setSkinID()
	{
		/*if( !isActive )
			return;

		if( @m_client == null || client.state() < CS_SPAWNED || client.getEnt().team == TEAM_SPECTATOR )
			return;
		for( uint i = 0; i < skinAchievements.length; i++ )
		{
			if( @skinAchievements[i] == null )
				continue;
			if( skinAchievements[i].active )
			{
				client.getEnt().skinNum = skinAchievements[i].skinID;
				break;
			}
		}*/
	}

	Client @get_client()
	{
		return m_client;
	}

	Entity @get_entity()
	{
		return ( @m_client == null ) ? null : m_client.getEnt();
	}
}
