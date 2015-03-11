// Copyright (C) 1989-1998 by Symantec
// Copyright (C) 2000-2011 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

//#pragma once
#ifndef TASSERT_H
#define TASSERT_H 1

/*****************************
 * Define a local assert function.
 */

#undef assert
#define assert(e)       ((e) || (util_assert(__FILE__, __LINE__), 0))

#if __clang__

void util_assert(const char * , int) __attribute__((noreturn));

#else

#if _MSC_VER
__declspec(noreturn)
#endif
void util_assert(const char *, int);

#if __DMC__
#pragma noreturn(util_assert)
#endif

#endif


#endif /* TASSERT_H */
