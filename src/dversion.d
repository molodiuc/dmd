// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.dversion;

import ddmd.arraytypes, ddmd.cond, ddmd.dmodule, ddmd.dmodule, ddmd.dscope, ddmd.dsymbol, ddmd.globals, ddmd.hdrgen, ddmd.identifier, ddmd.root.outbuffer, ddmd.visitor;

extern (C++) final class DebugSymbol : Dsymbol
{
public:
    uint level;

    /* ================================================== */
    /* DebugSymbol's happen for statements like:
     *      debug = identifier;
     *      debug = integer;
     */
    extern (D) this(Loc loc, Identifier ident)
    {
        super(ident);
        this.loc = loc;
    }

    extern (D) this(Loc loc, uint level)
    {
        super();
        this.level = level;
        this.loc = loc;
    }

    Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        auto ds = new DebugSymbol(loc, ident);
        ds.level = level;
        return ds;
    }

    char* toChars()
    {
        if (ident)
            return ident.toChars();
        else
        {
            OutBuffer buf;
            buf.printf("%d", level);
            return buf.extractString();
        }
    }

    int addMember(Scope* sc, ScopeDsymbol sds, int memnum)
    {
        //printf("DebugSymbol::addMember('%s') %s\n", sds->toChars(), toChars());
        Module m = sds.isModule();
        // Do not add the member to the symbol table,
        // just make sure subsequent debug declarations work.
        if (ident)
        {
            if (!m)
            {
                error("declaration must be at module level");
                errors = true;
            }
            else
            {
                if (findCondition(m.debugidsNot, ident))
                {
                    error("defined after use");
                    errors = true;
                }
                if (!m.debugids)
                    m.debugids = new Strings();
                m.debugids.push(ident.toChars());
            }
        }
        else
        {
            if (!m)
            {
                error("level declaration must be at module level");
                errors = true;
            }
            else
                m.debuglevel = level;
        }
        return 0;
    }

    void semantic(Scope* sc)
    {
        //printf("DebugSymbol::semantic() %s\n", toChars());
    }

    const(char)* kind()
    {
        return "debug";
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class VersionSymbol : Dsymbol
{
public:
    uint level;

    /* ================================================== */
    /* VersionSymbol's happen for statements like:
     *      version = identifier;
     *      version = integer;
     */
    extern (D) this(Loc loc, Identifier ident)
    {
        super(ident);
        this.loc = loc;
    }

    extern (D) this(Loc loc, uint level)
    {
        super();
        this.level = level;
        this.loc = loc;
    }

    Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        auto ds = new VersionSymbol(loc, ident);
        ds.level = level;
        return ds;
    }

    char* toChars()
    {
        if (ident)
            return ident.toChars();
        else
        {
            OutBuffer buf;
            buf.printf("%d", level);
            return buf.extractString();
        }
    }

    int addMember(Scope* sc, ScopeDsymbol sds, int memnum)
    {
        //printf("VersionSymbol::addMember('%s') %s\n", sds->toChars(), toChars());
        Module m = sds.isModule();
        // Do not add the member to the symbol table,
        // just make sure subsequent debug declarations work.
        if (ident)
        {
            VersionCondition.checkPredefined(loc, ident.toChars());
            if (!m)
            {
                error("declaration must be at module level");
                errors = true;
            }
            else
            {
                if (findCondition(m.versionidsNot, ident))
                {
                    error("defined after use");
                    errors = true;
                }
                if (!m.versionids)
                    m.versionids = new Strings();
                m.versionids.push(ident.toChars());
            }
        }
        else
        {
            if (!m)
            {
                error("level declaration must be at module level");
                errors = true;
            }
            else
                m.versionlevel = level;
        }
        return 0;
    }

    void semantic(Scope* sc)
    {
    }

    const(char)* kind()
    {
        return "version";
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}
