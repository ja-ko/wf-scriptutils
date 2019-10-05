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

namespace Serialization
{
	void SerializeStringDictionary( Dictionary @dict, String filename )
	{
		if( @dict == null )
			return;

		String output = "dict";

		String[]@ keys = dict.getKeys();
		if( @keys == null )
			return;

		for( uint i = 0; i < keys.length; i++ )
		{
			if( @keys[i] == null )
				continue;
			String @value;
			dict.get( keys[i], @value );
			if( @value == null )
				continue;
			output += keys[i] + "\u0002" + value + "\u0003";
		}

		if( filename.length() == 0 )
			return;

		::G_WriteFile( filename, output );
	}

	Dictionary@ DeserializeStringDictionary( String filename )
	{
		if( filename.length() == 0 || !::G_FileExists( filename ) )
			return null;

		String content = ::G_LoadFile( filename );
		if( content.substr( 0, 4 ) != "dict" )
			return null;

		content = content.substr( 4 );

		String@[]@ pairs = StringUtils::Split( content, "\u0003" );
		if( @pairs == null || pairs.length == 0 )
			return null;

		Dictionary dict();

		for( uint i = 0; i < pairs.length; i++ )
		{
			if( @pairs[i] == null )
				continue;
			String@[]@ parts = StringUtils::Split( pairs[i], "\u0002" );
			if( @parts == null || parts.length != 2 || @parts[0] == null || @parts[1] == null )
				continue;
			dict.set( parts[0], parts[1] );
		}

		return dict;
	}
}
