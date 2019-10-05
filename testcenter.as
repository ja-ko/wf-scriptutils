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

namespace TestCenter
{
    array<UnitTest@> testClasses;
    UnitTest@ singleTest = null;

    Logger@ LOG = null;
    String testProtocol;

    void Init()
    {
        @LOG = @Logger( "TestCenter" );
        FunctionCallCenter::SetTimeout( AfterInit, 500 ); // give the game some time to setup before we start doing things
    }

    void AfterInit()
    {
        Print( "-------------------------------------" );
        Print( "This is Kandru gametype Test-Center." );

        ::RegisterTests();

        StartTests();
    }

    void StartTests()
    {
        int countSuccess = 0;
        int countFailed = 0;

        if( @singleTest != null )
        {
            Print( "SingleTestMode activated." );
            Print( "SingleTestClass: " + singleTest.name );
            Print( "Executing..." );
            UnitTestResult@[]@ results = @singleTest.executeTests();
            for( uint i = 0; i < results.length; i++ )
            {
                Print( results[i] );
                if( results[i].successful )
                    countSuccess++;
                else
                    countFailed++;
            }
        }
        else
        {
            if( testClasses.length == 0 )
            {
                PrintError( "No tests found. Shutting down..." );
                ::G_CmdExecute( "killserver" );
                return;
            }
            for( uint i = 0; i < testClasses.length; i++ )
            {
                UnitTest @test = @testClasses[i];
                Print( "TestClass: " + test.name );
                Print( "Executing..." );
                UnitTestResult@[]@ results = @singleTest.executeTests();
                for( uint i = 0; i < results.length; i++ )
                {
                    Print( results[i] );
                    if( results[i].successful )
                        countSuccess++;
                    else
                        countFailed++;
                }
            }
        }

        int countTests = countFailed + countSuccess;
        Print( "-------------------------------------" );
        Print( "Testresult:" );
        Print( "OK: " + countSuccess + "/" + (countTests) + " (" + (int(float(countSuccess)/float(countTests)*100.0f)) + "%)" );
        Print( "Failed: " + countFailed + "/" + (countTests) + " (" + (int(float(countFailed)/float(countTests)*100.0f)) + "%)" );

        WriteFile();
    }

    void WriteFile()
    {
        Time now = Time( ::localTime );
        String filename = "protocol_" + ( 1900 + now.year ) + "-" + StringUtils::FormatInt( 1 + now.mon, "0", 2 )
                          + "-" + StringUtils::FormatInt( now.mday, "0", 2 ) + "_" + StringUtils::FormatInt( now.hour, "0", 2 )
                          + "-" + StringUtils::FormatInt( now.min, "0", 2 ) + "-" + StringUtils::FormatInt( now.sec, "0", 2 )
                          + ".results";

        ::G_AppendToFile( "testresults/" + filename, testProtocol );
        Print( "Wrote test protocol to testresults/" + filename + ". Shutting down." );
        ::G_CmdExecute( "killserver" );
    }

    void Print( String message )
    {
        testProtocol += message + "\n";
        ::G_Print( message + "\n" );
    }

    void PrintError( String message )
    {
        testProtocol += "[ERROR] " + message + "\n";
        LOG.logError( message );
    }

    void Print( UnitTestResult@ result )
    {
        if( @result == null )
            return;

        Print( "Test: " + result.name + ": " + ( result.successful ? "OK" : "FAILED" ) );
        if( result.summary != "" )
            Print( "Summary: " + result.summary );
    }

    void RegisterTest( UnitTest@ test )
    {
        testClasses.insertLast( test );
    }

    void RegisterSingleTest( UnitTest@ test )
    {
        if( @singleTest != null )
        {
            PrintError( "There is already a registered SingleUnitTest." );
            Print( "Shutting down." );
            WriteFile();
            ::G_CmdExecute( "killserver" );
        }
        @singleTest = @test;
    }
}

class UnitTestResult
{
    private String m_name;
    private String m_summary;
    private bool m_successful;

    UnitTestResult( bool successful, String summary )
    {
        m_successful = successful;
        m_name = "<NoNameSet>";
        m_summary = summary;
    }

    String get_name()
    {
        return m_name;
    }

    void set_name( String value )
    {
        m_name = value;
    }

    bool get_successful()
    {
        return m_successful;
    }

    String@ get_summary()
    {
        return m_summary;
    }
}

interface UnitTest
{
    String get_name();
    UnitTestResult@[]@ executeTests();
}

void GT_InitGametype()
{
    TestCenter::Init();

}
