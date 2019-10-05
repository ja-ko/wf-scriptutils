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

namespace StringUtils
{
	String RemoveInvalidPathChars( String input )
	{
		String ret = "";
		for( uint position = 0; position < input.len(); position++ )
		{
			String char;
			char = input.substr( position, 1 );
			if (char == '|' || char == '<' || char == '>' || char == '?' ||  char == '!' || char == '\\' || char == '%' || char == ':' || char == '*' || char == '\"' )
				ret += "_";
			else
				ret += input.substr( position, 1 );
		}
		return ret;
	}

	String Replace( String input, String search, String replace )
	{
		String ret = "";
		int i = 0;
		if( search.len() == 0 )
			return input;
		
		while( i < int(input.len()) )
		{
			if( input.substr( i, search.len() ) == search )
			{
				ret += replace;
				i += search.len();
			}
			else
			{
				ret +=input.substr( i, 1 );
				i++;
			}
		}
		return ret;
	}
}
