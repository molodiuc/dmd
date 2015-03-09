// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.root.response;

import core.stdc.stdio, core.stdc.stdlib, core.stdc.string;
import ddmd.root.file;

/*********************************
 * #include <stdlib.h>
 * int response_expand(int *pargc,char ***pargv);
 *
 * Expand any response files in command line.
 * Response files are arguments that look like:
 *   @NAME
 * The name is first searched for in the environment. If it is not
 * there, it is searched for as a file name.
 * Arguments are separated by spaces, tabs, or newlines. These can be
 * imbedded within arguments by enclosing the argument in '' or "".
 * Recursively expands nested response files.
 *
 * To use, put the line:
 *   response_expand(&argc,&argv);
 * as the first executable statement in main(int argc, char **argv).
 * argc and argv are adjusted to be the new command line arguments
 * after response file expansion.
 *
 * Digital Mars's MAKE program can be notified that a program can accept
 * long command lines via environment variables by preceding the rule
 * line for the program with a *.
 *
 * Returns:
 *   0   success
 *   !=0   failure (argc, argv unchanged)
 */
struct Narg
{
    size_t argc; // arg count
    size_t argvmax; // dimension of nargv[]
    const(char)** argv;
}

extern (C++) static bool addargp(Narg* n, const(char)* p)
{
    /* The 2 is to always allow room for a NULL argp at the end   */
    if (n.argc + 2 > n.argvmax)
    {
        n.argvmax = n.argc + 2;
        const(char)** ap = n.argv;
        ap = cast(const(char)**)realloc(ap, n.argvmax * (char*).sizeof);
        if (!ap)
        {
            if (n.argv)
                free(n.argv);
            memset(n, 0, (*n).sizeof);
            return true;
        }
        n.argv = ap;
    }
    n.argv[n.argc++] = p;
    return false;
}

extern (C++) bool response_expand(size_t* pargc, const(char)*** pargv)
{
    Narg n;
    const(char)* cp;
    int recurse = 0;
    n.argc = 0;
    n.argvmax = 0; /* dimension of n.argv[]      */
    n.argv = null;
    for (size_t i = 0; i < *pargc; ++i)
    {
        cp = (*pargv)[i];
        if (*cp != '@')
        {
            if (addargp(&n, (*pargv)[i]))
                goto noexpand;
            continue;
        }
        char* buffer;
        char* bufend;
        cp++;
        char* p = getenv(cp);
        if (p)
        {
            buffer = strdup(p);
            if (!buffer)
                goto noexpand;
            bufend = buffer + strlen(buffer);
        }
        else
        {
            auto f = File(cp);
            if (f.read())
                goto noexpand;
            f._ref = 1;
            buffer = cast(char*)f.buffer;
            bufend = buffer + f.len;
        }
        // The logic of this should match that in setargv()
        int comment = 0;
        for (p = buffer; p < bufend; p++)
        {
            char* d;
            char c, lastc;
            ubyte instring;
            int num_slashes, non_slashes;
            switch (*p)
            {
            case 26:
                /* ^Z marks end of file      */
                goto L2;
            case 0xD:
            case '\n':
                if (comment)
                {
                    comment = 0;
                }
                case 0:
            case ' ':
            case '\t':
                continue;
                // scan to start of argument
            case '#':
                comment = 1;
                continue;
            case '@':
                if (comment)
                {
                    continue;
                }
                recurse = 1;
            default:
                /* start of new argument   */
                if (comment)
                {
                    continue;
                }
                if (addargp(&n, p))
                    goto noexpand;
                instring = 0;
                c = 0;
                num_slashes = 0;
                for (d = p; 1; p++)
                {
                    lastc = c;
                    if (p >= bufend)
                    {
                        *d = 0;
                        goto L2;
                    }
                    c = *p;
                    switch (c)
                    {
                    case '"':
                        /*
                         Yes this looks strange,but this is so that we are
                         MS Compatible, tests have shown that:
                         \\\\"foo bar"  gets passed as \\foo bar
                         \\\\foo  gets passed as \\\\foo
                         \\\"foo gets passed as \"foo
                         and \"foo gets passed as "foo in VC!
                         */
                        non_slashes = num_slashes % 2;
                        num_slashes = num_slashes / 2;
                        for (; num_slashes > 0; num_slashes--)
                        {
                            d--;
                            *d = '\0';
                        }
                        if (non_slashes)
                        {
                            *(d - 1) = c;
                        }
                        else
                        {
                            instring ^= 1;
                        }
                        break;
                    case 26:
                        *d = 0; // terminate argument
                        goto L2;
                    case 0xD:
                        // CR
                        c = lastc;
                        continue;
                        // ignore
                    case '@':
                        recurse = 1;
                        goto Ladd;
                    case ' ':
                    case '\t':
                        if (!instring)
                    {
                        case '\n':
                        case 0:
                            *d = 0; // terminate argument
                            goto Lnextarg;
                        }
                        default:
                        Ladd:
                            if (c == '\\')
                                num_slashes++;
                            else
                                num_slashes = 0;
                        *d++ = c;
                        break;
                    }
                }
                break;
            }
        Lnextarg:
        }
    L2:
    }
    if (n.argvmax == 0)
    {
        n.argvmax = 1;
        n.argv = cast(const(char)**)calloc(n.argvmax, (char*).sizeof);
        if (!n.argv)
            return true;
    }
    else
        n.argv[n.argc] = null;
    if (recurse)
    {
        /* Recursively expand @filename   */
        if (response_expand(&n.argc, &n.argv))
            goto noexpand;
    }
    *pargc = n.argc;
    *pargv = n.argv;
    return false; /* success         */
noexpand:
    /* error         */
    free(n.argv);
    /* BUG: any file buffers are not free'd   */
    return true;
}
