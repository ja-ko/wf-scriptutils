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

funcdef bool GametypeCommand( Client @client, String &cmdString, String &argsString, int argc );
funcdef bool UpdateBotStatus( Entity @self );
funcdef Entity@ SelectSpawnpoint( Entity @self );
funcdef String@ BuildScoreboardMessage( uint maxlen );
funcdef void ScoreEvent( Client @client, String &score_event, String &args );
funcdef void PlayerRespawn( Entity @ent, int old_team, int new_team );
funcdef void ThinkRules();
funcdef bool MatchStateFinished( int incomingState );
funcdef void MatchStateStarted();
funcdef void GametypeShutdown();
funcdef void GametypeSpawn();

funcdef void TimeoutCallback();
funcdef void TimeoutCallbackArgument( any & arg );

funcdef bool IntervalCallback();
funcdef bool IntervalCallbackArgument( any & arg );

funcdef bool CommandHandle( Client @client, String &cmdString, String &argsString, int argc );

namespace FunctionCallCenter
{

	// Register Command Handler
	Dictionary @cmdlist_commands;

	uint RegisterCommand( String cmd, CommandHandle @cb )
	{
		if( @cmdlist_commands == null )
			@cmdlist_commands = Dictionary();

		if( cmd.len() == 0 || cb is null)
			return 0;

		array<CommandHandle@> handles;
		if( cmdlist_commands.exists( cmd ) )
		{
			cmdlist_commands.get( cmd, handles );
		}
		handles.insertLast( cb );
		cmdlist_commands.set( cmd, handles );

		::G_RegisterCommand( cmd );

		return uint( handles.length - 1 );
	}

	void UnRegisterCommand( String cmd, uint handle )
	{
		if( @cmdlist_commands == null )
			@cmdlist_commands = Dictionary();

		if( cmd.len() == 0 )
			return;

		array<CommandHandle@> handles;
		if( !cmdlist_commands.exists( cmd ) )
			return;

		cmdlist_commands.get( cmd, handles );
		if( handle >= handles.length )
			return;

		@handles[handle] = null;
		cmdlist_commands.set( cmd, handles );
	}

	bool ExecuteCommandListeners( Client @client, String &cmdString, String &argsString, int argc )
	{
		if( @client == null )
			return false;

		if( @cmdlist_commands == null )
			@cmdlist_commands = Dictionary();

		if( cmdString.len() == 0 )
			return false;

		if( !cmdlist_commands.exists( cmdString ) )
			return false;

		array<CommandHandle@> handles;
		cmdlist_commands.get( cmdString, handles );
		bool ret = false;
		for( uint i = 0; i < handles.length; i++ )
		{
			if( handles[i] is null )
				continue;
			CommandHandle @tmp = @handles[i];
			ret = ret || tmp(client, cmdString, argsString, argc);
		}
		return ret;
	}

	// function call scheduler

	array<TimeoutCallback@> cblist_timeout;
	array<uint> tolist_time;
	array<uint> tolist_active;

	array<TimeoutCallbackArgument@> cblist_timeoutarg;
	array<uint> toalist_time;
	array<any> toalist_arg;
	array<uint> toalist_active;

	array<IntervalCallback@> cblist_interval;
	array<uint> ivlist_time;
	array<uint> ivlist_interval;
	array<uint> ivlist_active;

	array<IntervalCallbackArgument@> cblist_intervalarg;
	array<uint> ivalist_time;
	array<uint> ivalist_interval;
	array<any> ivalist_arg;
	array<uint> ivalist_active;

	uint SetTimeout( TimeoutCallback @cb, uint timeout )
	{
		if( cb is null )
			return 0;

		cblist_timeout.insertLast( cb );
		uint index = uint(cblist_timeout.length - 1);
		tolist_time.insertLast( ::levelTime + timeout );
		tolist_active.insertLast( index );
		return index;
	}

	void RemoveTimeout( uint id )
	{
		for( uint i = 0; i < tolist_active.length; i++ )
		{
			if( tolist_active[i] == id )
				tolist_active.removeAt(i);
		}
	}

	uint SetTimeoutArg( TimeoutCallbackArgument @cb, uint timeout, any &in arg )
	{
		if( cb is null )
			return 0;

		cblist_timeoutarg.insertLast( cb );
		uint index = uint(cblist_timeoutarg.length - 1);
		toalist_time.insertLast( ::levelTime + timeout );
		toalist_arg.insertLast( arg );
		toalist_active.insertLast( index );
		return index;
	}

	void RemoveTimeoutArg( uint id )
	{
		for( uint i = 0; i < toalist_active.length; i++ )
		{
			if( toalist_active[i] == id )
			{
				toalist_active.removeAt(i);
				toalist_arg[id] = any(null);
			}
		}
	}

	uint SetInterval( IntervalCallback @cb, uint interval )
	{
		if( cb is null )
			return 0;

		cblist_interval.insertLast( cb );
		uint index = uint(cblist_interval.length - 1);
		ivlist_time.insertLast( ::levelTime );
		ivlist_interval.insertLast( interval );
		ivlist_active.insertLast( index );
		return index;
	}

	void RemoveInterval( uint id )
	{
		for( uint i = 0; i < ivlist_active.length; i++ )
		{
			if( ivlist_active[i] == id )
				ivlist_active.removeAt(i);
		}
	}

	uint SetIntervalArg( IntervalCallbackArgument @cb, uint interval, any &in arg )
	{
		if( cb is null )
			return 0;

		cblist_intervalarg.insertLast( cb );
		uint index = uint(cblist_intervalarg.length - 1);
		ivalist_time.insertLast( ::levelTime );
		ivalist_interval.insertLast( interval );
		ivalist_arg.insertLast( arg );
		ivalist_active.insertLast( index );
		return index;
	}

	void RemoveIntervalArg( uint id )
	{
		for( uint i = 0; i < ivalist_active.length; i++ )
		{
			if( ivalist_active[i] == id )
			{
				ivalist_active.removeAt(i);
				ivalist_arg[i] = any(null);
			}
		}
	}

	void callTimeouts()
	{
		for( uint i = 0; i < tolist_active.length; i++ )
		{
			if( tolist_time[tolist_active[i]] > ::levelTime )
				continue;
			TimeoutCallback @cb = @cblist_timeout[tolist_active[i]];
			if( cb is null )
				continue;
			cb();
			RemoveTimeout(tolist_active[i]);
		}
		for( uint i = 0; i < toalist_active.length; i++ )
		{
			if( toalist_time[toalist_active[i]] > ::levelTime )
				continue;
			TimeoutCallbackArgument @cb = @cblist_timeoutarg[toalist_active[i]];
			if( cb is null )
				continue;
			cb(toalist_arg[toalist_active[i]]);
			RemoveTimeoutArg(toalist_active[i]);
		}
	}

	void callIntervals()
	{
		for( uint i = 0; i < ivlist_active.length; i++ )
		{
			if( ivlist_time[ivlist_active[i]] + ivlist_interval[ivlist_active[i]] > ::levelTime )
				continue;
			IntervalCallback @cb = @cblist_interval[ivlist_active[i]];
			if( cb is null )
				continue;
			if( !cb() )
				ivlist_active.removeAt(i);
			else
				ivlist_time[ivlist_active[i]] = ::levelTime;
		}
		for( uint i = 0; i < ivalist_active.length; i++ )
		{
			if( ivalist_time[ivalist_active[i]] + ivalist_interval[ivalist_active[i]] > ::levelTime )
				continue;
			IntervalCallbackArgument @cb = @cblist_intervalarg[ivalist_active[i]];
			if( cb is null )
				continue;
			if( !cb(ivalist_arg[ivalist_active[i]]) )
				RemoveIntervalArg(ivalist_active[i]);
			else
				ivalist_time[ivalist_active[i]] = ::levelTime;
		}
	}

	// gametype interface
	array<ListenerHandle@> cblist_gamecommand;
	array<ListenerHandle@> cblist_botstatus;
	array<ListenerHandle@> cblist_spawnpoint;
	array<ListenerHandle@> cblist_scoreboard;
	array<ListenerHandle@> cblist_scoreevent;
	array<ListenerHandle@> cblist_respawn;
	array<ListenerHandle@> cblist_think;
	array<ListenerHandle@> cblist_statefinished;
	array<ListenerHandle@> cblist_statestarted;
	array<ListenerHandle@> cblist_shutdown;
	array<ListenerHandle@> cblist_spawn;

	bool AutoProceedMatchStates = false; // Proceed to next matchstate

	ListenerHandle@ RegisterGametypeCommandListener( GametypeCommand @callback )
	{
		ListenerHandle handle;
		@handle.cmdCb = @callback;
		cblist_gamecommand.insertLast( handle );
		return @handle;
	}

	void RemoveGametypeCommandListener( ListenerHandle @handle )
	{
		if( cblist_gamecommand.find( handle ) != -1 )
			cblist_gamecommand.removeAt( cblist_gamecommand.find( handle ) );
	}

	ListenerHandle@ RegisterUpdateBotStatusListener( UpdateBotStatus @callback )
	{
		ListenerHandle handle;
		@handle.botCb = @callback;
		cblist_botstatus.insertLast( handle );
		return @handle;
	}

	void RemoveUpdateBotStatusListener( ListenerHandle @handle )
	{
		if( cblist_botstatus.find( handle ) != -1 )
			cblist_botstatus.removeAt( cblist_botstatus.find( handle ) );
	}

	ListenerHandle@ RegisterSelectSpawnpointListener( SelectSpawnpoint @callback )
	{
		ListenerHandle handle;
		@handle.spawnpointCb = @callback;
		cblist_spawnpoint.insertLast( handle );
		return @handle;
	}

	void RemoveSelectSpawnpointListener( ListenerHandle @handle )
	{
		if( cblist_spawnpoint.find( handle ) != -1 )
			cblist_spawnpoint.removeAt( cblist_spawnpoint.find( handle ) );
	}

	ListenerHandle@ RegisterBuildScoreboardMessageListener( BuildScoreboardMessage @callback )
	{
		ListenerHandle handle;
		@handle.scoreboardCb = @callback;
		cblist_scoreboard.insertLast( handle );
		return @handle;
	}

	void RemoveBuildScoreboardMessageListener( ListenerHandle @handle )
	{
		if( cblist_scoreboard.find( handle ) != -1 )
			cblist_scoreboard.removeAt( cblist_scoreboard.find( handle ) );
	}

	ListenerHandle@ RegisterScoreEventListener( ScoreEvent @callback )
	{
		ListenerHandle handle;
		@handle.scoreCb = @callback;
		cblist_scoreevent.insertLast( handle );
		return @handle;
	}

	void RemoveScoreEventListener( ListenerHandle @handle )
	{
		if( cblist_scoreevent.find( handle ) != -1 )
			cblist_scoreevent.removeAt( cblist_scoreevent.find( handle ) );
	}

	ListenerHandle@ RegisterPlayerRespawnListener( PlayerRespawn @callback )
	{
		ListenerHandle handle;
		@handle.respawnCb = @callback;
		cblist_respawn.insertLast( handle );
		return @handle;
	}

	void RemovePlayerRespawnListener( ListenerHandle @handle )
	{
		if( cblist_respawn.find( handle ) != -1 )
			cblist_respawn.removeAt( cblist_respawn.find( handle ) );
	}

	ListenerHandle@ RegisterThinkRulesListener( ThinkRules @callback )
	{
		ListenerHandle handle;
		@handle.thinkCb = @callback;
		cblist_think.insertLast( handle );
		return @handle;
	}

	void RemoveThinkRulesListener( ListenerHandle @handle )
	{
		if( cblist_think.find( handle ) != -1 )
			cblist_think.removeAt( cblist_think.find( handle ) );
	}

	ListenerHandle@ RegisterMatchStateFinishedListener( MatchStateFinished @callback )
	{
		ListenerHandle handle;
		@handle.finishedCb = @callback;
		cblist_statefinished.insertLast( handle );
		return @handle;
	}

	void RemoveMatchStateFinishedListener( ListenerHandle @handle )
	{
		if( cblist_statefinished.find( handle ) != -1 )
			cblist_statefinished.removeAt( cblist_statefinished.find( handle ) );
	}

	ListenerHandle@ RegisterMatchStateStartedListener( MatchStateStarted @callback )
	{
		ListenerHandle handle;
		@handle.startedCb = @callback;
		cblist_statestarted.insertLast( handle );
		return @handle;
	}

	void RemoveMatchStateStartedListener( ListenerHandle @handle )
	{
		if( cblist_statestarted.find( handle ) != -1 )
			cblist_statestarted.removeAt( cblist_statestarted.find( handle ) );
	}

	ListenerHandle@ RegisterGametypeShutdownListener( GametypeShutdown @callback )
	{
		ListenerHandle handle;
		@handle.shutdownCb = @callback;
		cblist_shutdown.insertLast( handle );
		return @handle;
	}

	void RemoveGametypeShutdownListener( ListenerHandle @handle )
	{
		if( cblist_shutdown.find( handle ) != -1 )
			cblist_shutdown.removeAt( cblist_shutdown.find( handle ) );
	}

	ListenerHandle@ RegisterGametypeSpawnListener( GametypeSpawn @callback )
	{
		ListenerHandle handle;
		@handle.spawnCb = @callback;
		cblist_spawn.insertLast( handle );
		return @handle;
	}

	void RemoveGametypeSpawnListener( ListenerHandle @handle )
	{
		if( cblist_spawn.find( handle ) != -1 )
			cblist_spawn.removeAt( cblist_spawn.find( handle ) );
	}



	bool GT_Command( Client @client, String &cmdString, String &argsString, int argc )
	{
		bool ret = false;
		for( uint i = 0; i < cblist_gamecommand.length; i++ )
		{
			if( cblist_gamecommand[i] is null )
				continue;
			GametypeCommand @call = @cblist_gamecommand[i].cmdCb; // For some weird reason angelscript needs this
			bool tmp = call( client, cmdString, argsString, argc );
			ret = ret || tmp; // return true if a single Listener returned true
		}
		bool tmp = ExecuteCommandListeners( client, cmdString, argsString, argc );
		ret = ret || tmp;
		return ret;
	}

	bool GT_UpdateBotStatus( Entity @self )
	{
		bool ret = false;
		for( uint i = 0; i < cblist_botstatus.length; i++ )
		{
			if( cblist_botstatus[i] is null )
				continue;
			UpdateBotStatus @call = @cblist_botstatus[i].botCb;
			bool tmp = call( self );
			ret = ret || tmp; // Same here
		}
		return ret;
	}

	Entity @GT_SelectSpawnPoint( Entity @self )
	{
		Entity @ret = null;
		for( uint i = 0; i < cblist_spawnpoint.length; i++ )
		{
			if( cblist_spawnpoint[i] is null )
				continue;
			SelectSpawnpoint @call = @cblist_spawnpoint[i].spawnpointCb;
			Entity @tmp = @call( self );
			if( @tmp != null && @ret == null ) // This is different. We want to call all Listener, but we just return the first entity to the engine
				@ret = @tmp;
		}
		return ret;
	}

	String @GT_ScoreboardMessage( uint maxlen )
	{
		String ret = "";
		for( uint i = 0; i < cblist_scoreboard.length; i++ )
		{
			if( cblist_scoreboard[i] is null )
				continue;
			BuildScoreboardMessage @call = @cblist_scoreboard[i].scoreboardCb;
			String tmp = call( maxlen );
			if( tmp != "" && ret == "" ) // The spawnpoint concept applies to this function as well
				ret = tmp;
		}
		return ret;
	}

	void GT_scoreEvent( Client @client, String &score_event, String &args )
	{
		for( uint i = 0; i < cblist_scoreevent.length; i++ )
		{
			if( cblist_scoreevent[i] is null )
				continue;
			ScoreEvent @call = @cblist_scoreevent[i].scoreCb;
			call( client, score_event, args ); // Finally we don't need to return anything
		}
	}

	void GT_playerRespawn( Entity @ent, int old_team, int new_team )
	{
		for( uint i = 0; i < cblist_respawn.length; i++ )
		{
			if( cblist_respawn[i] is null )
				continue;
			PlayerRespawn @call = @cblist_respawn[i].respawnCb;
			call( ent, old_team, new_team );
		}
	}

	void GT_ThinkRules()
	{
		// First let the scheduler do it's things
		callIntervals();
		callTimeouts();
		// Then check whether we want to change the match state
		if( AutoProceedMatchStates )
		{
			if ( ::match.scoreLimitHit() || ::match.timeLimitHit() || ::match.suddenDeathFinished() )
				::match.launchState( ::match.getState() + 1 );
		}
		// Finally we can execute ThinkRules Listeners
		for( uint i = 0; i < cblist_think.length; i++ )
		{
			if( cblist_think[i] is null )
				continue;
			ThinkRules @call = @cblist_think[i].thinkCb;
			call();
		}
	}

	bool GT_MatchStateFinished( int incomingMatchState )
	{
		bool ret = true;
		for( uint i = 0; i < cblist_statefinished.length; i++ )
		{
			if( cblist_statefinished[i] is null )
				continue;
			MatchStateFinished @call = @cblist_statefinished[i].finishedCb;
			ret = ret && call( incomingMatchState ); // This one is defferent again. If a single Listener returns false, we have to return false
		}
		return ret;
	}

	void GT_MatchStateStarted()
	{
		for( uint i = 0; i < cblist_statestarted.length; i++ )
		{
			if( cblist_statestarted[i] is null )
				continue;
			MatchStateStarted @call = @cblist_statestarted[i].startedCb;
			call();
		}
	}

	void GT_Shutdown()
	{
		for( uint i = 0; i < cblist_shutdown.length; i++ )
		{
			if( cblist_shutdown[i] is null )
				continue;
			GametypeShutdown @call = @cblist_shutdown[i].shutdownCb;
			call();
		}
	}

	void GT_SpawnGametype()
	{
		for( uint i = 0; i < cblist_spawn.length; i++ )
		{
			if( cblist_spawn[i] is null )
				continue;

			GametypeSpawn @call = @cblist_spawn[i].spawnCb;
			call();
		}
	}
} // end of namespace FunctionCallCenter

class ListenerHandle
{
	ListenerHandle()
	{
		@cmdCb = null;
		@botCb = null;
		@spawnpointCb = null;
		@scoreboardCb = null;
		@scoreCb = null;
		@respawnCb = null;
		@thinkCb = null;
		@finishedCb = null;
		@startedCb = null;
		@shutdownCb = null;
		@spawnCb = null;
	}

	GametypeCommand @cmdCb;
	UpdateBotStatus @botCb;
	SelectSpawnpoint @spawnpointCb;
	BuildScoreboardMessage @scoreboardCb;
	ScoreEvent @scoreCb;
	PlayerRespawn @respawnCb;
	ThinkRules @thinkCb;
	MatchStateFinished @finishedCb;
	MatchStateStarted @startedCb;
	GametypeShutdown @shutdownCb;
	GametypeSpawn @spawnCb;

    bool opEquals( ListenerHandle @input )
	{
        if( @input == null )
            return false;

        return input is this;
	}
}

bool GT_Command( Client @client, const String &cmdString, const String &argsString, int argc )
{
	return FunctionCallCenter::GT_Command( client, cmdString, argsString, argc );
}

bool GT_UpdateBotStatus( Entity @self )
{
	return FunctionCallCenter::GT_UpdateBotStatus( self );
}

Entity @GT_SelectSpawnPoint( Entity @self )
{
	return FunctionCallCenter::GT_SelectSpawnPoint( self );
}

String @GT_ScoreboardMessage( uint maxlen )
{
	return FunctionCallCenter::GT_ScoreboardMessage( maxlen );
}

void GT_ScoreEvent( Client @client, const String &score_event, const String &args )
{
	FunctionCallCenter::GT_scoreEvent( client, score_event, args );
}

void GT_PlayerRespawn( Entity @ent, int old_team, int new_team )
{
	FunctionCallCenter::GT_playerRespawn( ent, old_team, new_team );
}

void GT_ThinkRules()
{
	FunctionCallCenter::GT_ThinkRules();
}

bool GT_MatchStateFinished( int incomingMatchState )
{
	return FunctionCallCenter::GT_MatchStateFinished( incomingMatchState );
}

void GT_MatchStateStarted()
{
	FunctionCallCenter::GT_MatchStateStarted();
}

void GT_Shutdown()
{
	FunctionCallCenter::GT_Shutdown();
}

void GT_SpawnGametype()
{
	FunctionCallCenter::GT_SpawnGametype();
}
