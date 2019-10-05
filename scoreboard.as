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

funcdef String PlayerScoreboardEntry( Entity @ent );
funcdef String PlayerScoreboardModify( Entity @ent, String entry );

namespace ScoreBoardHelper
{

	PlayerScoreboardEntry @callback;

	PlayerScoreboardModify @cbmodify;

	int picIndex_true;
	int picIndex_false;

	String ScoreboardLayout;

	String @ScoreboardMessage( uint maxlen )
	{
		if( ::gametype.isTeamBased )
			return ScoreboardMessageTeamBased( maxlen );
		else
			return ScoreboardMessageIndividual( maxlen );
	}

	String ScoreboardMessageTeamBased( uint maxlen )
	{
		String scoreboard = "", entry = "";

		for( int j = ::TEAM_ALPHA; j < ::GS_MAX_TEAMS; j++ )
		{
			Team @team = @::G_GetTeam( j );

			entry = "&t " + j + " " + team.stats.score + " 0 ";
			if( scoreboard.len() + entry.len() <= maxlen )
				scoreboard += entry;

			for( int i = 0; @team.ent( i ) != null; i++ )
			{
				Entity @ent = team.ent( i );
				if( callback is null )
					continue;

				entry = callback( ent ) + " ";

				if( cbmodify !is null )
					entry = cbmodify( ent, entry );

				if( scoreboard.len() + entry.len() <= maxlen )
					scoreboard += entry;
			}

		}
		return scoreboard;
	}

	String ScoreboardMessageIndividual( uint maxlen )
	{
		String scoreboard = "", entry = "";

		Team @team = @::G_GetTeam( ::TEAM_PLAYERS );

		entry = "&t " + int( ::TEAM_PLAYERS ) + " " + team.stats.score + " 0 ";
		if( scoreboard.len() + entry.len() <= maxlen )
			scoreboard += entry;

		for( int i = 0; @team.ent( i ) != null; i++ )
		{
			Entity @ent = team.ent( i );
			if( callback is null )
				continue;

			entry = callback( team.ent( i ) ) + " ";

			if( cbmodify !is null )
				entry = cbmodify( ent, entry );

			if( scoreboard.len() + entry.len() <= maxlen )
				scoreboard += entry;
		}
		return scoreboard;
	}

	int InactivePlayer( int playerNum )
	{
		if( playerNum < 0 || playerNum >= ::maxClients )
			return playerNum;
		else
			return -( playerNum + 1 );
	}

	int InactivePlayer( Entity @ent )
	{
		if( @ent == null || @ent.client == null )
			return ::maxClients;
		else
			return -( ent.client.playerNum + 1 );
	}

	int InactivePlayer( Client @client )
	{
		if( @client == null )
			return ::maxClients;
		else
			return -( client.playerNum + 1 );
	}

	int ConvertToPicture( bool input )
	{
		return input ? picIndex_true : picIndex_false;
	}

	void RegisterEntryModifier( PlayerScoreboardModify @cb )
	{
		@cbmodify = @cb;
	}

	void Init( PlayerScoreboardEntry @cb )
	{
		@callback = @cb;
		FunctionCallCenter::RegisterBuildScoreboardMessageListener( ScoreboardMessage );

		picIndex_true = ::G_ImageIndex( "gfx/hud/icons/vsay/yes" );
		picIndex_false = ::G_ImageIndex( "gfx/hud/icons/vsay/no" );
	}

	void SetLayout( String layout )
	{
		::G_ConfigString( ::CS_SCB_PLAYERTAB_LAYOUT, layout );
		ScoreboardLayout = layout;
	}

	void SetTitle( String title )
	{
		::G_ConfigString( ::CS_SCB_PLAYERTAB_TITLES, title );
	}

}
