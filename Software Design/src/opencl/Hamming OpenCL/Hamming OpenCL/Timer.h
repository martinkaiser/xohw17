/*!
 * \internal
 * \file Timer.h
 * \version Version: $Id$
 * \author  Song Ho Ahn (song.ahn@gmail.com)
 */
/////////////////////////////////////////////////////////////////////////////
// Timer.h
// =======
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

#ifndef TIMER_H_DEF
#define TIMER_H_DEF

#define DLL_PUBLIC_LIB 
#define SUB_BOOST_VERSION 0

/** @addtogroup statics
 *  @{
 */

/*!
	* \class Timer
	* \brief High Resolution Timer
	*
	* Platform independent timer that is able to measure the elapsed time with 1 micro-second accuracy
	*
	*/
class DLL_PUBLIC_LIB Timer
{
	public:
		Timer();                                    // default constructor
		~Timer();                                   // default destructor

        void   start();                             // start timer
        void   stop();                              // stop the timer
        double getElapsedTime();                    // get elapsed time in second
        double getElapsedTimeInSec();               // get elapsed time in second (same as getElapsedTime)
        double getElapsedTimeInMilliSec();          // get elapsed time in milli-second
        double getElapsedTimeInMicroSec();          // get elapsed time in micro-second

	private:
		Timer(const Timer &); // disable copy constructor
		Timer &operator=(const Timer &); //  disable assignment constructor
		class Timer_Private *d;
};
/** @} */

#endif // TIMER_H_DEF
