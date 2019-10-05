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
	testcenter.as
*/

class SimpleUnitTest
{
    String m_name;
    UnitTestResult@ lastResult;
    int testCount;

    int assertCount;

    SimpleUnitTest( String name )
    {
        m_name = name;
    }

    void setTestCount( int i )
    {
       testCount = i;
    }

    String callTest( int i )
    {
        return "";
    }

    String get_name()
    {
        return m_name;
    }

    UnitTestResult@[]@ executeTests()
    {
        array<UnitTestResult@> result;

        for( int i = 0; i < testCount; i++ )
        {
            assertCount = 0;
            @lastResult = UnitTestResult( true, "" );
            String name = callTest( i );
            lastResult.name = name;
            result.insertLast( lastResult );
        }
        return result;
    }

    bool assert( bool condition )
    {
        assertCount++;
        if( !condition )
        {
            String summary = "Assert #" + assertCount + " failed.";
            @lastResult = UnitTestResult( false, summary );
        }
        return !condition;
    }

    bool assert( String summary, bool condition )
    {
        assertCount++;
        if( !condition )
        {
            String text = "Assert #" + assertCount + " failed.\n";
            text += summary;
            @lastResult = UnitTestResult( false, text );
        }
        return !condition;
    }
}


class ExampleTest : SimpleUnitTest, UnitTest
{
    ExampleTest()
    {
        super("Example-Test");

        setTestCount( 2 );
    }

    String callTest( int i ) override
    {
        switch( i )
        {
            case 0:
                return testSomething();
            case 1:
                return testSomethingElse();
        }
        return "WrongIndex";
    }

    String testSomething()
    {
        String ret = "testSomething";

        // Do some stuff

        if( assert(true) )
            return ret;

        // Do some more stuff

        if( assert(true) )
            return ret;

        if( assert("Things went wrong", false) )
            return ret;

        return ret;
    }

    String testSomethingElse()
    {
        return "testSomethingElse";
    }
}
