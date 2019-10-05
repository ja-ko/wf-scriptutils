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

namespace Logger
{

    String writeFileName = "";

    void SetLogFileName( String filename )
    {
        writeFileName = filename;
    }

    void log( String code, String classname, String message )
    {
        String@ logMessage = ((code == "") ? ("[" + code + "] " ) : ("")) + "[" + classname + "]: " + message + "\n";
        if( writeFileName != "" )
        {
            ::G_AppendToFile( writeFileName, logMessage );
        }
        ::G_Print( logMessage );
    }
}

class Logger
{
    private String m_classname;

    Logger( String classname )
    {
        m_classname = classname;
    }

    void logError( String errorMessage )
    {
        writeMessage( "ERROR", errorMessage );
    }

    void logWarning( String warningMessage )
    {
        writeMessage( "WARNING", warningMessage );
    }

    void logDebug( String infoMessage )
    {
        writeMessage( "DEBUG", infoMessage );
    }

    void writeMessage( String code, String message )
    {
        Logger::log( code, m_classname, message );
    }
}
