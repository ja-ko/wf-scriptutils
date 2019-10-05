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

funcdef void ClientCvarChanged( Client @client, String cvar, String oldcontent, String newcontent );

namespace ClientCvar
{
	array<ClientCvar@> list_clientcvars;

	bool cb_init = false;

	String Get( Client @client, String name )
	{
		if( @client == null || client.state() < ::CS_SPAWNED )
			return "null";

		for( uint i = 0; i < list_clientcvars.length; i++ )
		{
			if( @list_clientcvars[i] != null && list_clientcvars[i].name == name )
			{
				if( list_clientcvars[i].exists( client ) && list_clientcvars[i].upToDate( client ) )
					return list_clientcvars[i].getValue( client );
				else if( list_clientcvars[i].exists( client ) && !list_clientcvars[i].upToDate( client ) )
					return "null";
				list_clientcvars[i].create( client );
				return list_clientcvars[i].standartValue;
			}
		}
		return "null";
	}

	void Set( Client @client, String name, String value )
	{
		if( @client == null || client.state() < ::CS_SPAWNED )
			return;
		for( uint i = 0; i < list_clientcvars.length; i++ )
		{
			if( @list_clientcvars[i] != null && list_clientcvars[i].name == name )
			{
				list_clientcvars[i].setValue( client, value );
				return;
			}
		}
	}

	void Register( String name, String standartcontent )
	{
		for( uint i = 0; i < list_clientcvars.length; i++ )
		{
			if( @list_clientcvars[i] != null && list_clientcvars[i].name == name )
				return; // already exists
		}
		list_clientcvars.insertLast( ClientCvar( name, standartcontent ) );
		list_clientcvars[list_clientcvars.length - 1].update();
		FunctionCallCenter::SetIntervalArg( Update, 5000, any(name) );
		if( !cb_init )
		{
			cb_init = true;
			FunctionCallCenter::RegisterGametypeCommandListener( CheckCvarResponse );
			FunctionCallCenter::RegisterScoreEventListener( ConnectionEvent );
		}
	}

	uint RegisterChangeCallback( String name, ClientCvarChanged @cb )
	{
		if( name.len() == 0 || cb is null )
			return 0;

		for( uint i = 0; i < list_clientcvars.length; i++ )
		{
			if( @list_clientcvars[i] != null && list_clientcvars[i].name == name )
				return list_clientcvars[i].registerChangeListener( cb );
		}
		return 0;
	}

	void RemoveChangeCallback( String name, uint cbindex )
	{
		if( name.len() == 0 )
			return;

		for( uint i = 0; i < list_clientcvars.length; i++ )
		{
			if( @list_clientcvars[i] != null && list_clientcvars[i].name == name )
				list_clientcvars[i].removeChangeListener( cbindex );
		}
	}

	bool Update( any &arg )
	{
		String cvarname;
		arg.retrieve( cvarname );
		if( cvarname.len() == 0 )
		{
			::G_Print( "ClientCvar: ERROR: Update() without argument!\n" );
			return false;
		}
		for( uint i = 0; i < list_clientcvars.length; i++ )
		{
			if( @list_clientcvars[i] != null && list_clientcvars[i].name == cvarname )
			{
				list_clientcvars[i].update();
				return true;
			}
		}
		return false;
	}

	bool CheckCvarResponse( Client @client, String &cmdString, String &argsString, int argc )
	{
		if( cmdString != "cvarinfo" )
			return false;


		String cvarname = argsString.getToken( 0 );

		for( uint i = 0; i < list_clientcvars.length; i++ )
		{
			if( @list_clientcvars[i] != null && list_clientcvars[i].name == cvarname )
				return list_clientcvars[i].handleClientAnswer( client, cmdString, argsString, argc );
		}
		return false;
	}

	void ConnectionEvent( Client @client, String &score_event, String &args )
	{
		if( @client == null )
			return;

		if( score_event == "enterGame" )
		{
			for( uint i = 0; i < list_clientcvars.length; i++ )
				list_clientcvars[i].update( client );
		}
		else if( score_event == "disconnect" )
		{
			for( uint i = 0; i < list_clientcvars.length; i++ )
				list_clientcvars[i].reset( client );
		}
	}
}

class ClientCvar
{
	private String m_cvarName;
	private array<String> m_cvarContent;
	private String m_standartContent;
	private array<bool> m_upToDate;
	private array<ClientCvarChanged@> m_changeCallbacks;

	ClientCvar( String name, String standartcontent )
	{
		m_cvarContent.length = maxClients;
		m_upToDate.length = maxClients;
		m_cvarName = name;
		for( int i = 0; i < maxClients; i++ )
		{
			m_cvarContent[i] = "";
			m_upToDate[i] = false;
		}
		m_standartContent = standartcontent;
	}

	void reset( Client @client )
	{
		if( @client == null )
			return;

		m_cvarContent[client.playerNum] = "";
		m_upToDate[client.playerNum] = false;
	}

	bool exists( Client @client )
	{
		if( @client == null )
			return false;

		return ( m_cvarContent[client.playerNum].len() != 0 && m_cvarContent[client.playerNum] != "not found" );
	}

	void create( Client @client )
	{
		if( @client == null || client.state() < CS_SPAWNED )
			return;

		if( !exists( client ) && m_upToDate[client.playerNum] )
			client.execGameCommand( "cmd seta " + m_cvarName + " \"" + m_standartContent +"\";\n" );
	}

	void update( Client @client )
	{
		if( @client == null || client.state() < CS_SPAWNED )
			return;

		G_CmdExecute( "cvarcheck " + client.playerNum + " \"" + m_cvarName + "\"\n" );
	}

	void update()
	{
		G_CmdExecute( "cvarcheck all \"" + m_cvarName + "\"\n" );
	}

	uint registerChangeListener( ClientCvarChanged@ cb )
	{
		if( cb is null )
			return 0;
		//if( m_changeCallbacks.find( @cb ) > -1 )
		//	return m_changeCallbacks.find( @cb );

		for( uint i = 0; i < m_changeCallbacks.length; i++ )
		{
            if( m_changeCallbacks[i] is cb )
                return i;
		}

		m_changeCallbacks.insertLast( cb );
		return uint( m_changeCallbacks.length - 1 );
	}

	void removeChangeListener( uint cbindex )
	{
		if( m_changeCallbacks.length <= cbindex )
			return;
		@m_changeCallbacks[cbindex] = null;
	}

	void callChangeCallbacks( Client @client, String oldcontent )
	{
		if( @client == null )
			return;

		for( uint i = 0; i < m_changeCallbacks.length; i++ )
		{
			ClientCvarChanged @cb = @m_changeCallbacks[i];
			if( cb is null )
				continue;
			cb( client, m_cvarName, oldcontent, m_cvarContent[client.playerNum] );
		}
	}

	bool handleClientAnswer( Client @client, String cmdString, String argsString, int argc )
	{
		if( @client == null )
			return false;

		if( cmdString != "cvarinfo" )
			return false;

		String cvarName = argsString.getToken( 0 );
		String cvarContent = argsString.getToken( 1 );

		if( cvarName != m_cvarName )
			return false;

		String oldContent = m_cvarContent[client.playerNum];
		bool wasUpToDate = m_upToDate[client.playerNum];

		m_cvarContent[client.playerNum] = cvarContent;
		m_upToDate[client.playerNum] = true;

		if( oldContent != cvarContent && cvarContent != "not found" && wasUpToDate )
			callChangeCallbacks( client, oldContent );

		if( !exists( client ) )
			create( client );

		return true;
	}

	String get_name()
	{
		return m_cvarName;
	}

	String getValue( Client @client )
	{
		if( @client == null || client.state() < CS_SPAWNED || !m_upToDate[client.playerNum] )
			return "null";
		return m_cvarContent[client.playerNum];
	}

	void setValue( Client @client, String value )
	{
		if( @client == null || client.state() < CS_SPAWNED || !m_upToDate[client.playerNum] )
			return;
		m_cvarContent[client.playerNum] = value;
		client.execGameCommand( "cmd seta " + m_cvarName + " \"" + value +"\";\n" );
	}

	String get_standartValue()
	{
		return m_standartContent;
	}

	bool upToDate( Client @client )
	{
		if( @client == null || client.state() < CS_SPAWNED )
			return false;
		return m_upToDate[client.playerNum];
	}
}
