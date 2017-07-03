
/*!
 * \internal
 * \file Timer.cpp
 * \version Version: $Id$
 * \author  Song Ho Ahn (song.ahn@gmail.com)
 */

//////////////////////////////////////////////////////////////////////////////
// Timer.cpp
// =========
// High Resolution Timer.
// This timer is able to measure the elapsed time with 1 micro-second accuracy
// in both Windows, Linux and Unix system
//
//  AUTHOR: Song Ho Ahn (song.ahn@gmail.com)
// CREATED: 2003-01-13
// UPDATED: 2006-01-13
//
// Copyright (c) 2003 Song Ho Ahn
//////////////////////////////////////////////////////////////////////////////

#include "Timer.h"

#if SUB_BOOST_VERSION < 47
#ifdef _WIN32   // Windows system specific
#include <windows.h>
#else          // Unix based system specific
#include <sys/time.h>
#endif
#else
#define BOOST_TIME
#include <boost/chrono.hpp>
#endif
#include <cmath>

class Timer_Private
{
public:
    Timer_Private() :
        stopped(0),
    #ifdef BOOST_TIME
        m_StartTime(boost::chrono::high_resolution_clock::now()),
        m_EndTime(boost::chrono::high_resolution_clock::now())
  #else
        startTimeInMicroSec(0.0),
        endTimeInMicroSec(0.0),
    #ifdef WIN32
        frequency(),
        startCount(),
        endCount()
  #else
        startCount(),
        endCount()
  #endif
  #endif
    {
#ifndef BOOST_TIME
#ifdef WIN32
        frequency.QuadPart = 0;
        startCount.QuadPart = 0;
        endCount.QuadPart = 0;
        QueryPerformanceFrequency(&frequency);
        startCount.QuadPart = 0;
        endCount.QuadPart = 0;
#else
        startCount.tv_sec = startCount.tv_usec = 0;
        endCount.tv_sec = endCount.tv_usec = 0;
#endif

        startTimeInMicroSec = 0;
        endTimeInMicroSec = 0;
#endif
    }

    void start()
    {
        stopped = 0; // reset stop flag
#ifdef BOOST_TIME
        m_StartTime = boost::chrono::high_resolution_clock::now();
#else
#ifdef WIN32
        QueryPerformanceCounter(&startCount);
#else
        gettimeofday(&startCount, nullptr);
#endif
#endif
    }

    void stop()
    {
        stopped = 1; // set timer stopped flag

#ifdef BOOST_TIME
        m_EndTime = boost::chrono::high_resolution_clock::now();
#else
#ifdef WIN32
        QueryPerformanceCounter(&endCount);
#else
        gettimeofday(&endCount, nullptr);
#endif
#endif
    }

    double getElapsedTimeInMicroSec()
    {
#ifdef BOOST_TIME
        boost::chrono::microseconds mic;
        if(!stopped)
            mic = boost::chrono::duration_cast<boost::chrono::microseconds>(boost::chrono::high_resolution_clock::now() - m_StartTime);
        else
            mic = boost::chrono::duration_cast<boost::chrono::microseconds>(m_EndTime - m_StartTime);

        return (double)mic.count();
#else
#ifdef WIN32
        if(!stopped)
            QueryPerformanceCounter(&endCount);

        startTimeInMicroSec = startCount.QuadPart * (1000000.0 / frequency.QuadPart);
        endTimeInMicroSec = endCount.QuadPart * (1000000.0 / frequency.QuadPart);
#else
        if(!stopped)
            gettimeofday(&endCount, nullptr);

        startTimeInMicroSec = (startCount.tv_sec * 1000000.0) + startCount.tv_usec;
        endTimeInMicroSec = (endCount.tv_sec * 1000000.0) + endCount.tv_usec;
#endif
        return endTimeInMicroSec - startTimeInMicroSec;
#endif
    }

private:
    int    stopped;                             // stop flag

#ifdef BOOST_TIME
    boost::chrono::high_resolution_clock::time_point m_StartTime;
    boost::chrono::high_resolution_clock::time_point m_EndTime;
#else
    double startTimeInMicroSec;                 // starting time in micro-second
    double endTimeInMicroSec;                   // ending time in micro-second
#ifdef WIN32
    LARGE_INTEGER frequency;                    // ticks per second
    LARGE_INTEGER startCount;                   //
    LARGE_INTEGER endCount;                     //
#else
    timeval startCount;                         //
    timeval endCount;                           //
#endif
#endif
};

///////////////////////////////////////////////////////////////////////////////
// constructor
///////////////////////////////////////////////////////////////////////////////
Timer::Timer()	:	d(new Timer_Private())
{
}



///////////////////////////////////////////////////////////////////////////////
// distructor
///////////////////////////////////////////////////////////////////////////////
Timer::~Timer()
{
    delete(d);
}



///////////////////////////////////////////////////////////////////////////////
// start timer.
// startCount will be set at this point.
///////////////////////////////////////////////////////////////////////////////
void Timer::start()
{
    d->start();
}



///////////////////////////////////////////////////////////////////////////////
// stop the timer.
// endCount will be set at this point.
///////////////////////////////////////////////////////////////////////////////
void Timer::stop()
{
    d->stop();
}



///////////////////////////////////////////////////////////////////////////////
// compute elapsed time in micro-second resolution.
// other getElapsedTime will call this first, then convert to correspond resolution.
///////////////////////////////////////////////////////////////////////////////
double Timer::getElapsedTimeInMicroSec()
{
    return d->getElapsedTimeInMicroSec();
}



///////////////////////////////////////////////////////////////////////////////
// divide elapsedTimeInMicroSec by 1000
///////////////////////////////////////////////////////////////////////////////
double Timer::getElapsedTimeInMilliSec()
{
    return d->getElapsedTimeInMicroSec() * 0.001;
}



///////////////////////////////////////////////////////////////////////////////
// divide elapsedTimeInMicroSec by 1000000
///////////////////////////////////////////////////////////////////////////////
double Timer::getElapsedTimeInSec()
{
    return d->getElapsedTimeInMicroSec() * 0.000001;
}



///////////////////////////////////////////////////////////////////////////////
// same as getElapsedTimeInSec()
///////////////////////////////////////////////////////////////////////////////
double Timer::getElapsedTime()
{
    return getElapsedTimeInSec();
}
