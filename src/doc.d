// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.doc;

import core.stdc.ctype, core.stdc.stdlib, core.stdc.string, core.stdc.time;
import ddmd.aggregate, ddmd.arraytypes, ddmd.attrib, ddmd.dclass, ddmd.declaration, ddmd.denum, ddmd.dmacro, ddmd.dmodule, ddmd.dscope, ddmd.dstruct, ddmd.dsymbol, ddmd.dtemplate, ddmd.errors, ddmd.func, ddmd.globals, ddmd.hdrgen, ddmd.id, ddmd.identifier, ddmd.lexer, ddmd.mars, ddmd.mtype, ddmd.root.aav, ddmd.root.array, ddmd.root.file, ddmd.root.filename, ddmd.root.outbuffer, ddmd.root.port, ddmd.root.rmem, ddmd.tokens, ddmd.utf, ddmd.visitor;

struct Escape
{
    const(char)*[256] strings;

    /***************************************
     * Find character string to replace c with.
     */
    extern (C++) const(char)* escapeChar(uint c)
    {
        version (all)
        {
            assert(c < 256);
            //printf("escapeChar('%c') => %p, %p\n", c, strings, strings[c]);
            return strings[c];
        }
        else
        {
            const(char)* s;
            switch (c)
            {
            case '<':
                s = "&lt;";
                break;
            case '>':
                s = "&gt;";
                break;
            case '&':
                s = "&amp;";
                break;
            default:
                s = null;
                break;
            }
            return s;
        }
    }
}

extern (C++) class Section
{
public:
    const(char)* name;
    size_t namelen;
    const(char)* _body;
    size_t bodylen;
    int nooutput;

    /***************************************************
     */
    void write(DocComment* dc, Scope* sc, Dsymbol s, OutBuffer* buf)
    {
        if (namelen)
        {
            static __gshared const(char)** table = ["AUTHORS", "BUGS", "COPYRIGHT", "DATE", "DEPRECATED", "EXAMPLES", "HISTORY", "LICENSE", "RETURNS", "SEE_ALSO", "STANDARDS", "THROWS", "VERSION", null];
            for (size_t i = 0; table[i]; i++)
            {
                if (icmp(table[i], name, namelen) == 0)
                {
                    buf.printf("$(DDOC_%s ", table[i]);
                    goto L1;
                }
            }
            buf.writestring("$(DDOC_SECTION ");
            // Replace _ characters with spaces
            buf.writestring("$(DDOC_SECTION_H ");
            size_t o = buf.offset;
            for (size_t u = 0; u < namelen; u++)
            {
                char c = name[u];
                buf.writeByte((c == '_') ? ' ' : c);
            }
            escapeStrayParenthesis(buf, o, s);
            buf.writestring(":)\n");
        }
        else
        {
            buf.writestring("$(DDOC_DESCRIPTION ");
        }
    L1:
        size_t o = buf.offset;
        buf.write(_body, bodylen);
        escapeStrayParenthesis(buf, o, s);
        highlightText(sc, s, buf, o);
        buf.writestring(")\n");
    }
}

extern (C++) final class ParamSection : Section
{
public:
    /***************************************************
     */
    void write(DocComment* dc, Scope* sc, Dsymbol s, OutBuffer* buf)
    {
        const(char)* p = _body;
        size_t len = bodylen;
        const(char)* pend = p + len;
        const(char)* tempstart = null;
        size_t templen = 0;
        const(char)* namestart = null;
        size_t namelen = 0; // !=0 if line continuation
        const(char)* textstart = null;
        size_t textlen = 0;
        size_t o, paramcount = 0;
        Parameter fparam = null;
        buf.writestring("$(DDOC_PARAMS ");
        while (p < pend)
        {
            // Skip to start of macro
            while (1)
            {
                switch (*p)
                {
                case ' ':
                case '\t':
                    p++;
                    continue;
                case '\n':
                    p++;
                    goto Lcont;
                default:
                    if (isIdStart(p) || isCVariadicArg(p, pend - p))
                        break;
                    if (namelen)
                        goto Ltext;
                    // continuation of prev macro
                    goto Lskipline;
                }
                break;
            }
            tempstart = p;
            while (isIdTail(p))
                p += utfStride(p);
            if (isCVariadicArg(p, pend - p))
                p += 3;
            templen = p - tempstart;
            while (*p == ' ' || *p == '\t')
                p++;
            if (*p != '=')
            {
                if (namelen)
                    goto Ltext;
                // continuation of prev macro
                goto Lskipline;
            }
            p++;
            if (namelen)
            {
                // Output existing param
            L1:
                //printf("param '%.*s' = '%.*s'\n", namelen, namestart, textlen, textstart);
                ++paramcount;
                HdrGenState hgs;
                buf.writestring("$(DDOC_PARAM_ROW ");
                buf.writestring("$(DDOC_PARAM_ID ");
                o = buf.offset;
                fparam = isFunctionParameter(s, namestart, namelen);
                bool isCVariadic = isCVariadicParameter(s, namestart, namelen);
                if (isCVariadic)
                {
                    buf.writestring("...");
                }
                else if (fparam && fparam.type && fparam.ident)
                {
                    .toCBuffer(fparam.type, buf, fparam.ident, &hgs);
                }
                else
                {
                    if (isTemplateParameter(s, namestart, namelen))
                    {
                        // 10236: Don't count template parameters for params check
                        --paramcount;
                    }
                    else if (!fparam)
                    {
                        warning(s.loc, "Ddoc: function declaration has no parameter '%.*s'", namelen, namestart);
                    }
                    buf.write(namestart, namelen);
                }
                escapeStrayParenthesis(buf, o, s);
                highlightCode(sc, s, buf, o, false);
                buf.writestring(")\n");
                buf.writestring("$(DDOC_PARAM_DESC ");
                o = buf.offset;
                buf.write(textstart, textlen);
                escapeStrayParenthesis(buf, o, s);
                highlightText(sc, s, buf, o);
                buf.writestring(")");
                buf.writestring(")\n");
                namelen = 0;
                if (p >= pend)
                    break;
            }
            namestart = tempstart;
            namelen = templen;
            while (*p == ' ' || *p == '\t')
                p++;
            textstart = p;
            Ltext: while (*p != '\n')
                p++;
            textlen = p - textstart;
            p++;
        Lcont:
            continue;
        Lskipline:
            // Ignore this line
            while (*p++ != '\n')
            {
            }
        }
        if (namelen)
            goto L1;
        // write out last one
        buf.writestring(")\n");
        TypeFunction tf = isTypeFunction(s);
        if (tf)
        {
            size_t pcount = (tf.parameters ? tf.parameters.dim : 0) + cast(int)(tf.varargs == 1);
            if (pcount != paramcount)
            {
                warning(s.loc, "Ddoc: parameter count mismatch");
            }
        }
    }
}

extern (C++) final class MacroSection : Section
{
public:
    /***************************************************
     */
    void write(DocComment* dc, Scope* sc, Dsymbol s, OutBuffer* buf)
    {
        //printf("MacroSection::write()\n");
        DocComment.parseMacros(dc.pescapetable, dc.pmacrotable, _body, bodylen);
    }
}

alias Sections = Array!(Section);

// Workaround for missing Parameter instance for variadic params. (it's unnecessary to instantiate one).
extern (C++) bool isCVariadicParameter(Dsymbol s, const(char)* p, size_t len)
{
    TypeFunction tf = isTypeFunction(s);
    return tf && tf.varargs == 1 && cmp("...", p, len) == 0;
}

extern (C++) static TemplateDeclaration getEponymousParentTemplate(Dsymbol s)
{
    if (!s.parent)
        return null;
    TemplateDeclaration td = s.parent.isTemplateDeclaration();
    return (td && td.onemember == s) ? td : null;
}

extern (C++) __gshared const(char)* ddoc_default = "DDOC =  <html><head>\n        <META http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">\n        <title>$(TITLE)</title>\n        </head><body>\n        <h1>$(TITLE)</h1>\n        $(BODY)\n        <hr>$(SMALL Page generated by $(LINK2 http://dlang.org/ddoc.html, Ddoc). $(COPYRIGHT))\n        </body></html>\n\nB =     <b>$0</b>\nI =     <i>$0</i>\nU =     <u>$0</u>\nP =     <p>$0</p>\nDL =    <dl>$0</dl>\nDT =    <dt>$0</dt>\nDD =    <dd>$0</dd>\nTABLE = <table>$0</table>\nTR =    <tr>$0</tr>\nTH =    <th>$0</th>\nTD =    <td>$0</td>\nOL =    <ol>$0</ol>\nUL =    <ul>$0</ul>\nLI =    <li>$0</li>\nBIG =   <big>$0</big>\nSMALL = <small>$0</small>\nBR =    <br>\nLINK =  <a href=\"$0\">$0</a>\nLINK2 = <a href=\"$1\">$+</a>\nLPAREN= (\nRPAREN= )\nBACKTICK= `\nDOLLAR= $\nDEPRECATED= $0\n\nRED =   <font color=red>$0</font>\nBLUE =  <font color=blue>$0</font>\nGREEN = <font color=green>$0</font>\nYELLOW =<font color=yellow>$0</font>\nBLACK = <font color=black>$0</font>\nWHITE = <font color=white>$0</font>\n\nD_CODE = <pre class=\"d_code\">$0</pre>\nDDOC_BACKQUOTED = $(D_INLINECODE $0)\nD_INLINECODE = <pre style=\"display:inline;\" class=\"d_inline_code\">$0</pre>\nD_COMMENT = $(GREEN $0)\nD_STRING  = $(RED $0)\nD_KEYWORD = $(BLUE $0)\nD_PSYMBOL = $(U $0)\nD_PARAM   = $(I $0)\n\nDDOC_COMMENT   = <!-- $0 -->\nDDOC_DECL      = $(DT $(BIG $0))\nDDOC_DECL_DD   = $(DD $0)\nDDOC_DITTO     = $(BR)$0\nDDOC_SECTIONS  = $0\nDDOC_SUMMARY   = $0$(BR)$(BR)\nDDOC_DESCRIPTION = $0$(BR)$(BR)\nDDOC_AUTHORS   = $(B Authors:)$(BR)\n$0$(BR)$(BR)\nDDOC_BUGS      = $(RED BUGS:)$(BR)\n$0$(BR)$(BR)\nDDOC_COPYRIGHT = $(B Copyright:)$(BR)\n$0$(BR)$(BR)\nDDOC_DATE      = $(B Date:)$(BR)\n$0$(BR)$(BR)\nDDOC_DEPRECATED = $(RED Deprecated:)$(BR)\n$0$(BR)$(BR)\nDDOC_EXAMPLES  = $(B Examples:)$(BR)\n$0$(BR)$(BR)\nDDOC_HISTORY   = $(B History:)$(BR)\n$0$(BR)$(BR)\nDDOC_LICENSE   = $(B License:)$(BR)\n$0$(BR)$(BR)\nDDOC_RETURNS   = $(B Returns:)$(BR)\n$0$(BR)$(BR)\nDDOC_SEE_ALSO  = $(B See Also:)$(BR)\n$0$(BR)$(BR)\nDDOC_STANDARDS = $(B Standards:)$(BR)\n$0$(BR)$(BR)\nDDOC_THROWS    = $(B Throws:)$(BR)\n$0$(BR)$(BR)\nDDOC_VERSION   = $(B Version:)$(BR)\n$0$(BR)$(BR)\nDDOC_SECTION_H = $(B $0)$(BR)\nDDOC_SECTION   = $0$(BR)$(BR)\nDDOC_MEMBERS   = $(DL $0)\nDDOC_MODULE_MEMBERS = $(DDOC_MEMBERS $0)\nDDOC_CLASS_MEMBERS  = $(DDOC_MEMBERS $0)\nDDOC_STRUCT_MEMBERS = $(DDOC_MEMBERS $0)\nDDOC_ENUM_MEMBERS   = $(DDOC_MEMBERS $0)\nDDOC_TEMPLATE_MEMBERS = $(DDOC_MEMBERS $0)\nDDOC_ENUM_BASETYPE = $0\nDDOC_PARAMS    = $(B Params:)$(BR)\n$(TABLE $0)$(BR)\nDDOC_PARAM_ROW = $(TR $0)\nDDOC_PARAM_ID  = $(TD $0)\nDDOC_PARAM_DESC = $(TD $0)\nDDOC_BLANKLINE  = $(BR)$(BR)\n\nDDOC_ANCHOR     = <a name=\"$1\"></a>\nDDOC_PSYMBOL    = $(U $0)\nDDOC_PSUPER_SYMBOL = $(U $0)\nDDOC_KEYWORD    = $(B $0)\nDDOC_PARAM      = $(I $0)\n\nESCAPES = /</&lt;/\n          />/&gt;/\n          /&/&amp;/\n";
extern (C++) __gshared const(char)* ddoc_decl_s = "$(DDOC_DECL ";
extern (C++) __gshared const(char)* ddoc_decl_e = ")\n";
extern (C++) __gshared const(char)* ddoc_decl_dd_s = "$(DDOC_DECL_DD ";
extern (C++) __gshared const(char)* ddoc_decl_dd_e = ")\n";

/****************************************************
 */
extern (C++) void gendocfile(Module m)
{
    static __gshared OutBuffer mbuf;
    static __gshared int mbuf_done;
    OutBuffer buf;
    //printf("Module::gendocfile()\n");
    if (!mbuf_done) // if not already read the ddoc files
    {
        mbuf_done = 1;
        // Use our internal default
        mbuf.write(ddoc_default, strlen(ddoc_default));
        // Override with DDOCFILE specified in the sc.ini file
        char* p = getenv("DDOCFILE");
        if (p)
            global.params.ddocfiles.shift(p);
        // Override with the ddoc macro files from the command line
        for (size_t i = 0; i < global.params.ddocfiles.dim; i++)
        {
            auto f = FileName((*global.params.ddocfiles)[i]);
            auto file = File(&f);
            readFile(m.loc, &file);
            // BUG: convert file contents to UTF-8 before use
            //printf("file: '%.*s'\n", file.len, file.buffer);
            mbuf.write(file.buffer, file.len);
        }
    }
    DocComment.parseMacros(&m.escapetable, &m.macrotable, cast(char*)mbuf.data, mbuf.offset);
    Scope* sc = Scope.createGlobal(m); // create root scope
    sc.docbuf = &buf;
    DocComment* dc = DocComment.parse(sc, m, m.comment);
    dc.pmacrotable = &m.macrotable;
    dc.pescapetable = &m.escapetable;
    // Generate predefined macros
    // Set the title to be the name of the module
    {
        const(char)* p = m.toPrettyChars();
        Macro.define(&m.macrotable, cast(char*)"TITLE", 5, cast(char*)p, strlen(p));
    }
    // Set time macros
    {
        time_t t;
        time(&t);
        char* p = ctime(&t);
        p = mem.xstrdup(p);
        Macro.define(&m.macrotable, cast(char*)"DATETIME", 8, cast(char*)p, strlen(p));
        Macro.define(&m.macrotable, cast(char*)"YEAR", 4, cast(char*)p + 20, 4);
    }
    char* srcfilename = m.srcfile.toChars();
    Macro.define(&m.macrotable, cast(char*)"SRCFILENAME", 11, cast(char*)srcfilename, strlen(srcfilename));
    char* docfilename = m.docfile.toChars();
    Macro.define(&m.macrotable, cast(char*)"DOCFILENAME", 11, cast(char*)docfilename, strlen(docfilename));
    if (dc.copyright)
    {
        dc.copyright.nooutput = 1;
        Macro.define(&m.macrotable, cast(char*)"COPYRIGHT", 9, dc.copyright._body, dc.copyright.bodylen);
    }
    buf.printf("$(DDOC_COMMENT Generated by Ddoc from %s)\n", m.srcfile.toChars());
    if (m.isDocFile)
    {
        size_t commentlen = strlen(cast(char*)m.comment);
        if (dc.macros)
        {
            commentlen = dc.macros.name - m.comment;
            dc.macros.write(dc, sc, m, sc.docbuf);
        }
        sc.docbuf.write(m.comment, commentlen);
        highlightText(sc, m, sc.docbuf, 0);
    }
    else
    {
        dc.writeSections(sc, m, sc.docbuf);
        emitMemberComments(m, sc);
    }
    //printf("BODY= '%.*s'\n", buf.offset, buf.data);
    Macro.define(&m.macrotable, cast(char*)"BODY", 4, cast(char*)buf.data, buf.offset);
    OutBuffer buf2;
    buf2.writestring("$(DDOC)\n");
    size_t end = buf2.offset;
    m.macrotable.expand(&buf2, 0, &end, null, 0);
    version (all)
    {
        /* Remove all the escape sequences from buf2,
         * and make CR-LF the newline.
         */
        {
            buf.setsize(0);
            buf.reserve(buf2.offset);
            char* p = cast(char*)buf2.data;
            for (size_t j = 0; j < buf2.offset; j++)
            {
                char c = p[j];
                if (c == 0xFF && j + 1 < buf2.offset)
                {
                    j++;
                    continue;
                }
                if (c == '\n')
                    buf.writeByte('\r');
                else if (c == '\r')
                {
                    buf.writestring("\r\n");
                    if (j + 1 < buf2.offset && p[j + 1] == '\n')
                    {
                        j++;
                    }
                    continue;
                }
                buf.writeByte(c);
            }
        }
        // Transfer image to file
        assert(m.docfile);
        m.docfile.setbuffer(buf.data, buf.offset);
        m.docfile._ref = 1;
        ensurePathToNameExists(Loc(), m.docfile.toChars());
        writeFile(m.loc, m.docfile);
    }
    else
    {
        /* Remove all the escape sequences from buf2
         */
        {
            size_t i = 0;
            char* p = buf2.data;
            for (size_t j = 0; j < buf2.offset; j++)
            {
                if (p[j] == 0xFF && j + 1 < buf2.offset)
                {
                    j++;
                    continue;
                }
                p[i] = p[j];
                i++;
            }
            buf2.setsize(i);
        }
        // Transfer image to file
        m.docfile.setbuffer(buf2.data, buf2.offset);
        m.docfile._ref = 1;
        ensurePathToNameExists(Loc(), m.docfile.toChars());
        writeFile(m.loc, m.docfile);
    }
}

/****************************************************
 * Having unmatched parentheses can hose the output of Ddoc,
 * as the macros depend on properly nested parentheses.
 * This function replaces all ( with $(LPAREN) and ) with $(RPAREN)
 * to preserve text literally. This also means macros in the
 * text won't be expanded.
 */
extern (C++) void escapeDdocString(OutBuffer* buf, size_t start)
{
    for (size_t u = start; u < buf.offset; u++)
    {
        char c = buf.data[u];
        switch (c)
        {
        case '$':
            buf.remove(u, 1);
            buf.insert(u, cast(const(char)*)"$(DOLLAR)", 9);
            u += 8;
            break;
        case '(':
            buf.remove(u, 1); //remove the (
            buf.insert(u, cast(const(char)*)"$(LPAREN)", 9); //insert this instead
            u += 8; //skip over newly inserted macro
            break;
        case ')':
            buf.remove(u, 1); //remove the )
            buf.insert(u, cast(const(char)*)"$(RPAREN)", 9); //insert this instead
            u += 8; //skip over newly inserted macro
            break;
        default:
            break;
        }
    }
}

/****************************************************
 * Having unmatched parentheses can hose the output of Ddoc,
 * as the macros depend on properly nested parentheses.
 
 * Fix by replacing unmatched ( with $(LPAREN) and unmatched ) with $(RPAREN).
 */
extern (C++) void escapeStrayParenthesis(OutBuffer* buf, size_t start, Dsymbol s)
{
    uint par_open = 0;
    Loc loc = s.loc;
    if (Module m = s.isModule())
    {
        if (m.md)
            loc = m.md.loc;
    }
    for (size_t u = start; u < buf.offset; u++)
    {
        char c = buf.data[u];
        switch (c)
        {
        case '(':
            par_open++;
            break;
        case ')':
            if (par_open == 0)
            {
                //stray ')'
                warning(loc, "Ddoc: Stray ')'. This may cause incorrect Ddoc output. Use $(RPAREN) instead for unpaired right parentheses.");
                buf.remove(u, 1); //remove the )
                buf.insert(u, cast(const(char)*)"$(RPAREN)", 9); //insert this instead
                u += 8; //skip over newly inserted macro
            }
            else
                par_open--;
            break;
            version (none)
            {
                // For this to work, loc must be set to the beginning of the passed
                // text which is currently not possible
                // (loc is set to the Loc of the Dsymbol)
                case '\n':
                    loc.linnum++;
                    break;
                }
                default:
                    break;
                }
    }
    if (par_open) // if any unmatched lparens
    {
        par_open = 0;
        for (size_t u = buf.offset; u > start;)
        {
            u--;
            char c = buf.data[u];
            switch (c)
            {
            case ')':
                par_open++;
                break;
            case '(':
                if (par_open == 0)
                {
                    //stray '('
                    warning(loc, "Ddoc: Stray '('. This may cause incorrect Ddoc output. Use $(LPAREN) instead for unpaired left parentheses.");
                    buf.remove(u, 1); //remove the (
                    buf.insert(u, cast(const(char)*)"$(LPAREN)", 9); //insert this instead
                }
                else
                    par_open--;
                break;
            default:
                break;
            }
        }
    }
}

// Basically, this is to skip over things like private{} blocks in a struct or
// class definition that don't add any components to the qualified name.
extern (C++) static Scope* skipNonQualScopes(Scope* sc)
{
    while (sc && !sc.scopesym)
        sc = sc.enclosing;
    return sc;
}

extern (C++) static bool emitAnchorName(OutBuffer* buf, Dsymbol s, Scope* sc)
{
    if (!s || s.isPackage() || s.isModule())
        return false;
    // Add parent names first
    bool dot = false;
    if (s.parent)
        dot = emitAnchorName(buf, s.parent, sc);
    else if (sc)
        dot = emitAnchorName(buf, sc.scopesym, skipNonQualScopes(sc.enclosing));
    // Eponymous template members can share the parent anchor name
    if (getEponymousParentTemplate(s))
        return dot;
    if (dot)
        buf.writeByte('.');
    // Use "this" not "__ctor"
    TemplateDeclaration td;
    if (s.isCtorDeclaration() || ((td = s.isTemplateDeclaration()) !is null && td.onemember && td.onemember.isCtorDeclaration()))
    {
        buf.writestring("this");
    }
    else
    {
        /* We just want the identifier, not overloads like TemplateDeclaration::toChars.
         * We don't want the template parameter list and constraints. */
        buf.writestring(s.Dsymbol.toChars());
    }
    return true;
}

extern (C++) static void emitAnchor(OutBuffer* buf, Dsymbol s, Scope* sc)
{
    Identifier ident;
    {
        OutBuffer anc;
        emitAnchorName(&anc, s, skipNonQualScopes(sc));
        ident = Identifier.idPool(anc.peekString());
    }
    size_t* count = cast(size_t*)dmd_aaGet(&sc.anchorCounts, cast(void*)ident);
    TemplateDeclaration td = getEponymousParentTemplate(s);
    // don't write an anchor for matching consecutive ditto symbols
    if (*count > 0 && sc.prevAnchor == ident && sc.lastdc && (isDitto(s.comment) || (td && isDitto(td.comment))))
        return;
    (*count)++;
    // cache anchor name
    sc.prevAnchor = ident;
    buf.writestring("$(DDOC_ANCHOR ");
    buf.writestring(ident.string);
    // only append count once there's a duplicate
    if (*count != 1)
        buf.printf(".%u", *count);
    buf.writeByte(')');
}

/******************************* emitComment **********************************/
/** Get leading indentation from 'src' which represents lines of code. */
extern (C++) static size_t getCodeIndent(const(char)* src)
{
    while (src && (*src == '\r' || *src == '\n'))
        ++src; // skip until we find the first non-empty line
    size_t codeIndent = 0;
    while (src && (*src == ' ' || *src == '\t'))
    {
        codeIndent++;
        src++;
    }
    return codeIndent;
}

extern (C++) void emitUnittestComment(Scope* sc, Dsymbol s, size_t ofs)
{
    OutBuffer* buf = sc.docbuf;
    for (UnitTestDeclaration utd = s.ddocUnittest; utd; utd = utd.ddocUnittest)
    {
        if (utd.protection.kind == PROTprivate || !utd.comment || !utd.fbody)
            continue;
        // Strip whitespaces to avoid showing empty summary
        const(char)* c = utd.comment;
        while (*c == ' ' || *c == '\t' || *c == '\n' || *c == '\r')
            ++c;
        OutBuffer codebuf;
        codebuf.writestring("$(DDOC_EXAMPLES ");
        size_t o = codebuf.offset;
        codebuf.writestring(cast(char*)c);
        if (utd.codedoc)
        {
            size_t i = getCodeIndent(utd.codedoc);
            while (i--)
                codebuf.writeByte(' ');
            codebuf.writestring("----\n");
            codebuf.writestring(utd.codedoc);
            codebuf.writestring("----\n");
            highlightText(sc, s, &codebuf, o);
        }
        codebuf.writestring(")");
        buf.insert(ofs, codebuf.data, codebuf.offset);
        ofs += codebuf.offset;
        sc.lastoffset2 = ofs;
    }
}

/*
 * Emit doc comment to documentation file
 */
extern (C++) void emitDitto(Dsymbol s, Scope* sc)
{
    //printf("Dsymbol::emitDitto() %s %s\n", kind(), toChars());
    OutBuffer* buf = sc.docbuf;
    OutBuffer b;
    b.writestring("$(DDOC_DITTO ");
    size_t o = b.offset;
    toDocBuffer(s, &b, sc);
    //printf("b: '%.*s'\n", b.offset, b.data);
    /* If 'this' is a function template, then highlightCode() was
     * already run by FuncDeclaration::toDocbuffer().
     */
    if (!getEponymousParentTemplate(s))
        highlightCode(sc, s, &b, o);
    b.writeByte(')');
    buf.spread(sc.lastoffset, b.offset);
    memcpy(buf.data + sc.lastoffset, b.data, b.offset);
    sc.lastoffset += b.offset;
    sc.lastoffset2 += b.offset;
    Dsymbol p = s;
    if (!s.ddocUnittest && s.parent)
        p = s.parent.isTemplateDeclaration();
    if (p)
        emitUnittestComment(sc, p, sc.lastoffset2);
}

/** Recursively expand template mixin member docs into the scope. */
extern (C++) static void expandTemplateMixinComments(TemplateMixin tm, Scope* sc)
{
    if (!tm.semanticRun)
        tm.semantic(sc);
    TemplateDeclaration td = (tm && tm.tempdecl) ? tm.tempdecl.isTemplateDeclaration() : null;
    if (td && td.members)
    {
        for (size_t i = 0; i < td.members.dim; i++)
        {
            Dsymbol sm = (*td.members)[i];
            TemplateMixin tmc = sm.isTemplateMixin();
            if (tmc && tmc.comment)
                expandTemplateMixinComments(tmc, sc);
            else
                emitComment(sm, sc);
        }
    }
}

extern (C++) void emitMemberComments(ScopeDsymbol sds, Scope* sc)
{
    //printf("ScopeDsymbol::emitMemberComments() %s\n", toChars());
    OutBuffer* buf = sc.docbuf;
    if (sds.members)
    {
        const(char)* m = "$(DDOC_MEMBERS ";
        if (sds.isModule())
            m = "$(DDOC_MODULE_MEMBERS ";
        else if (sds.isClassDeclaration())
            m = "$(DDOC_CLASS_MEMBERS ";
        else if (sds.isStructDeclaration())
            m = "$(DDOC_STRUCT_MEMBERS ";
        else if (sds.isEnumDeclaration())
            m = "$(DDOC_ENUM_MEMBERS ";
        else if (sds.isTemplateDeclaration())
            m = "$(DDOC_TEMPLATE_MEMBERS ";
        size_t offset1 = buf.offset; // save starting offset
        buf.writestring(m);
        size_t offset2 = buf.offset; // to see if we write anything
        sc = sc.push(sds);
        for (size_t i = 0; i < sds.members.dim; i++)
        {
            Dsymbol s = (*sds.members)[i];
            //printf("\ts = '%s'\n", s->toChars());
            // only expand if parent is a non-template (semantic won't work)
            if (s.comment && s.isTemplateMixin() && s.parent && !s.parent.isTemplateDeclaration())
                expandTemplateMixinComments(cast(TemplateMixin)s, sc);
            emitComment(s, sc);
        }
        sc.pop();
        if (buf.offset == offset2)
        {
            /* Didn't write out any members, so back out last write
             */
            buf.offset = offset1;
        }
        else
            buf.writestring(")\n");
    }
}

extern (C++) void emitProtection(OutBuffer* buf, Prot prot)
{
    if (prot.kind != PROTundefined && prot.kind != PROTpublic)
    {
        protectionToBuffer(buf, prot);
        buf.writeByte(' ');
    }
}

extern (C++) void emitComment(Dsymbol s, Scope* sc)
{
    extern (C++) final class EmitComment : Visitor
    {
        alias visit = super.visit;
    public:
        Scope* sc;

        extern (D) this(Scope* sc)
        {
            this.sc = sc;
        }

        void visit(Dsymbol)
        {
        }

        void visit(InvariantDeclaration)
        {
        }

        void visit(UnitTestDeclaration)
        {
        }

        void visit(PostBlitDeclaration)
        {
        }

        void visit(DtorDeclaration)
        {
        }

        void visit(StaticCtorDeclaration)
        {
        }

        void visit(StaticDtorDeclaration)
        {
        }

        void visit(ClassInfoDeclaration)
        {
        }

        void visit(TypeInfoDeclaration)
        {
        }

        void visit(Declaration d)
        {
            //printf("Declaration::emitComment(%p '%s'), comment = '%s'\n", d, d->toChars(), d->comment);
            //printf("type = %p\n", d->type);
            if (d.protection.kind == PROTprivate || sc.protection.kind == PROTprivate || !d.ident || (!d.type && !d.isCtorDeclaration() && !d.isAliasDeclaration()))
                return;
            if (!d.comment)
                return;
            OutBuffer* buf = sc.docbuf;
            DocComment* dc = DocComment.parse(sc, d, d.comment);
            if (!dc)
            {
                emitDitto(d, sc);
                return;
            }
            dc.pmacrotable = &sc._module.macrotable;
            buf.writestring(ddoc_decl_s);
            size_t o = buf.offset;
            toDocBuffer(d, buf, sc);
            highlightCode(sc, d, buf, o);
            sc.lastoffset = buf.offset;
            buf.writestring(ddoc_decl_e);
            buf.writestring(ddoc_decl_dd_s);
            dc.writeSections(sc, d, buf);
            buf.writestring(ddoc_decl_dd_e);
        }

        void visit(AggregateDeclaration ad)
        {
            //printf("AggregateDeclaration::emitComment() '%s'\n", ad->toChars());
            if (ad.prot().kind == PROTprivate || sc.protection.kind == PROTprivate)
                return;
            if (!ad.comment)
                return;
            OutBuffer* buf = sc.docbuf;
            DocComment* dc = DocComment.parse(sc, ad, ad.comment);
            if (!dc)
            {
                emitDitto(ad, sc);
                return;
            }
            dc.pmacrotable = &sc._module.macrotable;
            buf.writestring(ddoc_decl_s);
            size_t o = buf.offset;
            toDocBuffer(ad, buf, sc);
            highlightCode(sc, ad, buf, o);
            sc.lastoffset = buf.offset;
            buf.writestring(ddoc_decl_e);
            buf.writestring(ddoc_decl_dd_s);
            dc.writeSections(sc, ad, buf);
            emitMemberComments(ad, sc);
            buf.writestring(ddoc_decl_dd_e);
        }

        void visit(TemplateDeclaration td)
        {
            //printf("TemplateDeclaration::emitComment() '%s', kind = %s\n", td->toChars(), td->kind());
            if (td.prot().kind == PROTprivate || sc.protection.kind == PROTprivate)
                return;
            const(char)* com = td.comment;
            bool hasmembers = true;
            Dsymbol ss = td;
            if (td.onemember)
            {
                ss = td.onemember.isAggregateDeclaration();
                if (!ss)
                {
                    ss = td.onemember.isFuncDeclaration();
                    if (ss)
                    {
                        hasmembers = false;
                        if (com != ss.comment)
                            com = Lexer.combineComments(com, ss.comment);
                    }
                    else
                        ss = td;
                }
            }
            if (!com)
                return;
            OutBuffer* buf = sc.docbuf;
            DocComment* dc = DocComment.parse(sc, td, com);
            size_t o;
            if (!dc)
            {
                emitDitto(ss, sc);
                return;
            }
            dc.pmacrotable = &sc._module.macrotable;
            buf.writestring(ddoc_decl_s);
            o = buf.offset;
            toDocBuffer(ss, buf, sc);
            if (ss == td)
                highlightCode(sc, td, buf, o);
            sc.lastoffset = buf.offset;
            buf.writestring(ddoc_decl_e);
            buf.writestring(ddoc_decl_dd_s);
            dc.writeSections(sc, td, buf);
            if (hasmembers)
                emitMemberComments(cast(ScopeDsymbol)ss, sc);
            buf.writestring(ddoc_decl_dd_e);
        }

        void visit(EnumDeclaration ed)
        {
            if (ed.prot().kind == PROTprivate || sc.protection.kind == PROTprivate)
                return;
            if (ed.isAnonymous() && ed.members)
            {
                for (size_t i = 0; i < ed.members.dim; i++)
                {
                    Dsymbol s = (*ed.members)[i];
                    emitComment(s, sc);
                }
                return;
            }
            if (!ed.comment)
                return;
            if (ed.isAnonymous())
                return;
            OutBuffer* buf = sc.docbuf;
            DocComment* dc = DocComment.parse(sc, ed, ed.comment);
            if (!dc)
            {
                emitDitto(ed, sc);
                return;
            }
            dc.pmacrotable = &sc._module.macrotable;
            buf.writestring(ddoc_decl_s);
            size_t o = buf.offset;
            toDocBuffer(ed, buf, sc);
            highlightCode(sc, ed, buf, o);
            sc.lastoffset = buf.offset;
            buf.writestring(ddoc_decl_e);
            buf.writestring(ddoc_decl_dd_s);
            dc.writeSections(sc, ed, buf);
            emitMemberComments(ed, sc);
            buf.writestring(ddoc_decl_dd_e);
        }

        void visit(EnumMember em)
        {
            //printf("EnumMember::emitComment(%p '%s'), comment = '%s'\n", em, em->toChars(), em->comment);
            if (em.prot().kind == PROTprivate || sc.protection.kind == PROTprivate)
                return;
            if (!em.comment)
                return;
            OutBuffer* buf = sc.docbuf;
            DocComment* dc = DocComment.parse(sc, em, em.comment);
            if (!dc)
            {
                emitDitto(em, sc);
                return;
            }
            dc.pmacrotable = &sc._module.macrotable;
            buf.writestring(ddoc_decl_s);
            size_t o = buf.offset;
            toDocBuffer(em, buf, sc);
            highlightCode(sc, em, buf, o);
            sc.lastoffset = buf.offset;
            buf.writestring(ddoc_decl_e);
            buf.writestring(ddoc_decl_dd_s);
            dc.writeSections(sc, em, buf);
            buf.writestring(ddoc_decl_dd_e);
        }

        void visit(AttribDeclaration ad)
        {
            //printf("AttribDeclaration::emitComment(sc = %p)\n", sc);
            /* A general problem with this, illustrated by BUGZILLA 2516,
             * is that attributes are not transmitted through to the underlying
             * member declarations for template bodies, because semantic analysis
             * is not done for template declaration bodies
             * (only template instantiations).
             * Hence, Ddoc omits attributes from template members.
             */
            Dsymbols* d = ad.include(null, null);
            if (d)
            {
                for (size_t i = 0; i < d.dim; i++)
                {
                    Dsymbol s = (*d)[i];
                    //printf("AttribDeclaration::emitComment %s\n", s->toChars());
                    emitComment(s, sc);
                }
            }
        }

        void visit(ProtDeclaration pd)
        {
            if (pd.decl)
            {
                sc = sc.push();
                sc.protection = pd.protection;
                visit(cast(AttribDeclaration)pd);
                sc = sc.pop();
            }
        }

        void visit(ConditionalDeclaration cd)
        {
            //printf("ConditionalDeclaration::emitComment(sc = %p)\n", sc);
            if (cd.condition.inc)
            {
                visit(cast(AttribDeclaration)cd);
            }
            else if (sc.docbuf)
            {
                /* If generating doc comment, be careful because if we're inside
                 * a template, then include(NULL, NULL) will fail.
                 */
                Dsymbols* d = cd.decl ? cd.decl : cd.elsedecl;
                for (size_t i = 0; i < d.dim; i++)
                {
                    Dsymbol s = (*d)[i];
                    emitComment(s, sc);
                }
            }
        }
    }

    scope EmitComment v = new EmitComment(sc);
    s.accept(v);
}

/******************************* toDocBuffer **********************************/
extern (C++) void toDocBuffer(Dsymbol s, OutBuffer* buf, Scope* sc)
{
    extern (C++) final class ToDocBuffer : Visitor
    {
        alias visit = super.visit;
    public:
        OutBuffer* buf;
        Scope* sc;

        extern (D) this(OutBuffer* buf, Scope* sc)
        {
            this.buf = buf;
            this.sc = sc;
        }

        void visit(Dsymbol s)
        {
            //printf("Dsymbol::toDocbuffer() %s\n", s->toChars());
            HdrGenState hgs;
            hgs.ddoc = true;
            .toCBuffer(s, buf, &hgs);
        }

        void prefix(Dsymbol s)
        {
            if (s.isDeprecated())
                buf.writestring("deprecated ");
            Declaration d = s.isDeclaration();
            if (d)
            {
                emitProtection(buf, d.protection);
                if (d.isStatic())
                    buf.writestring("static ");
                else if (d.isFinal())
                    buf.writestring("final ");
                else if (d.isAbstract())
                    buf.writestring("abstract ");
                if (!d.isFuncDeclaration()) // functionToBufferFull handles this
                {
                    if (d.isConst())
                        buf.writestring("const ");
                    if (d.isImmutable())
                        buf.writestring("immutable ");
                    if (d.isSynchronized())
                        buf.writestring("synchronized ");
                }
            }
        }

        void declarationToDocBuffer(Declaration decl, TemplateDeclaration td)
        {
            //printf("declarationToDocBuffer() %s, originalType = %s, td = %s\n", decl->toChars(), decl->originalType ? decl->originalType->toChars() : "--", td ? td->toChars() : "--");
            if (decl.ident)
            {
                if (decl.isDeprecated())
                    buf.writestring("$(DEPRECATED ");
                prefix(decl);
                if (decl.type)
                {
                    HdrGenState hgs;
                    hgs.ddoc = true;
                    Type origType = decl.originalType ? decl.originalType : decl.type;
                    if (origType.ty == Tfunction)
                    {
                        functionToBufferFull(cast(TypeFunction)origType, buf, decl.ident, &hgs, td);
                    }
                    else
                        .toCBuffer(origType, buf, decl.ident, &hgs);
                }
                else
                    buf.writestring(decl.ident.toChars());
                // emit constraints if declaration is a templated declaration
                if (td && td.constraint)
                {
                    HdrGenState hgs;
                    hgs.ddoc = true;
                    buf.writestring(" if (");
                    .toCBuffer(td.constraint, buf, &hgs);
                    buf.writeByte(')');
                }
                if (decl.isDeprecated())
                    buf.writestring(")");
                buf.writestring(";\n");
            }
        }

        void visit(Declaration d)
        {
            declarationToDocBuffer(d, null);
        }

        void visit(AliasDeclaration ad)
        {
            //printf("AliasDeclaration::toDocbuffer() %s\n", ad->toChars());
            if (ad.ident)
            {
                if (ad.isDeprecated())
                    buf.writestring("deprecated ");
                emitProtection(buf, ad.protection);
                buf.printf("alias %s = ", ad.toChars());
                if (Dsymbol s = ad.aliassym) // ident alias
                {
                    prettyPrintDsymbol(s, ad.parent);
                }
                else if (Type type = ad.getType()) // type alias
                {
                    if (type.ty == Tclass || type.ty == Tstruct || type.ty == Tenum)
                    {
                        if (Dsymbol s = type.toDsymbol(null)) // elaborate type
                            prettyPrintDsymbol(s, ad.parent);
                        else
                            buf.writestring(type.toChars());
                    }
                    else
                    {
                        // simple type
                        buf.writestring(type.toChars());
                    }
                }
                buf.writestring(";\n");
            }
        }

        void parentToBuffer(Dsymbol s)
        {
            if (s && !s.isPackage() && !s.isModule())
            {
                parentToBuffer(s.parent);
                buf.writestring(s.toChars());
                buf.writestring(".");
            }
        }

        static bool inSameModule(Dsymbol s, Dsymbol p)
        {
            for (; s; s = s.parent)
            {
                if (s.isModule())
                    break;
            }
            for (; p; p = p.parent)
            {
                if (p.isModule())
                    break;
            }
            return s == p;
        }

        void prettyPrintDsymbol(Dsymbol s, Dsymbol parent)
        {
            if (s.parent && (s.parent == parent)) // in current scope -> naked name
            {
                buf.writestring(s.toChars());
            }
            else if (!inSameModule(s, parent)) // in another module -> full name
            {
                buf.writestring(s.toPrettyChars());
            }
            else // nested in a type in this module -> full name w/o module name
            {
                // if alias is nested in a user-type use module-scope lookup
                if (!parent.isModule() && !parent.isPackage())
                    buf.writestring(".");
                parentToBuffer(s.parent);
                buf.writestring(s.toChars());
            }
        }

        void visit(FuncDeclaration fd)
        {
            //printf("FuncDeclaration::toDocbuffer() %s\n", fd->toChars());
            if (fd.ident)
            {
                TemplateDeclaration td = getEponymousParentTemplate(fd);
                if (td)
                {
                    /* It's a function template
                     */
                    size_t o = buf.offset;
                    declarationToDocBuffer(fd, td);
                    highlightCode(sc, fd, buf, o);
                }
                else
                {
                    visit(cast(Declaration)fd);
                }
            }
        }

        void visit(AggregateDeclaration ad)
        {
            if (ad.ident)
            {
                version (none)
                {
                    emitProtection(buf, ad.protection);
                }
                buf.printf("%s %s", ad.kind(), ad.toChars());
                buf.writestring(";\n");
            }
        }

        void visit(StructDeclaration sd)
        {
            //printf("StructDeclaration::toDocbuffer() %s\n", sd->toChars());
            if (sd.ident)
            {
                version (none)
                {
                    emitProtection(buf, sd.protection);
                }
                TemplateDeclaration td = getEponymousParentTemplate(sd);
                if (td)
                {
                    size_t o = buf.offset;
                    toDocBuffer(td, buf, sc);
                    highlightCode(sc, sd, buf, o);
                }
                else
                {
                    buf.printf("%s %s", sd.kind(), sd.toChars());
                }
                buf.writestring(";\n");
            }
        }

        void visit(ClassDeclaration cd)
        {
            //printf("ClassDeclaration::toDocbuffer() %s\n", cd->toChars());
            if (cd.ident)
            {
                version (none)
                {
                    emitProtection(buf, cd.protection);
                }
                TemplateDeclaration td = getEponymousParentTemplate(cd);
                if (td)
                {
                    size_t o = buf.offset;
                    toDocBuffer(td, buf, sc);
                    highlightCode(sc, cd, buf, o);
                }
                else
                {
                    if (!cd.isInterfaceDeclaration() && cd.isAbstract())
                        buf.writestring("abstract ");
                    buf.printf("%s %s", cd.kind(), cd.toChars());
                }
                int any = 0;
                for (size_t i = 0; i < cd.baseclasses.dim; i++)
                {
                    BaseClass* bc = (*cd.baseclasses)[i];
                    if (bc.protection.kind == PROTprivate)
                        continue;
                    if (bc.base && bc.base.ident == Id.Object)
                        continue;
                    if (any)
                        buf.writestring(", ");
                    else
                    {
                        buf.writestring(": ");
                        any = 1;
                    }
                    emitProtection(buf, bc.protection);
                    if (bc.base)
                    {
                        buf.printf("$(DDOC_PSUPER_SYMBOL %s)", bc.base.toPrettyChars());
                    }
                    else
                    {
                        HdrGenState hgs;
                        .toCBuffer(bc.type, buf, null, &hgs);
                    }
                }
                buf.writestring(";\n");
            }
        }

        void visit(EnumDeclaration ed)
        {
            if (ed.ident)
            {
                buf.printf("%s %s", ed.kind(), ed.toChars());
                if (ed.memtype)
                {
                    buf.writestring(": $(DDOC_ENUM_BASETYPE ");
                    HdrGenState hgs;
                    .toCBuffer(ed.memtype, buf, null, &hgs);
                    buf.writestring(")");
                }
                buf.writestring(";\n");
            }
        }

        void visit(EnumMember em)
        {
            if (em.ident)
            {
                buf.writestring(em.toChars());
            }
        }
    }

    scope ToDocBuffer v = new ToDocBuffer(buf, sc);
    s.accept(v);
}

struct DocComment
{
    Sections sections; // Section*[]
    Section summary;
    Section copyright;
    Section macros;
    Macro** pmacrotable;
    Escape** pescapetable;

    /********************************* DocComment *********************************/
    extern (C++) static DocComment* parse(Scope* sc, Dsymbol s, const(char)* comment)
    {
        //printf("parse(%s): '%s'\n", s->toChars(), comment);
        if (sc.lastdc && isDitto(comment))
            return null;
        auto dc = new DocComment();
        if (!comment)
            return dc;
        dc.parseSections(comment);
        for (size_t i = 0; i < dc.sections.dim; i++)
        {
            Section sec = dc.sections[i];
            if (icmp("copyright", sec.name, sec.namelen) == 0)
            {
                dc.copyright = sec;
            }
            if (icmp("macros", sec.name, sec.namelen) == 0)
            {
                dc.macros = sec;
            }
        }
        sc.lastdc = dc;
        return dc;
    }

    /************************************************
     * Parse macros out of Macros: section.
     * Macros are of the form:
     *      name1 = value1
     *
     *      name2 = value2
     */
    extern (C++) static void parseMacros(Escape** pescapetable, Macro** pmacrotable, const(char)* m, size_t mlen)
    {
        const(char)* p = m;
        size_t len = mlen;
        const(char)* pend = p + len;
        const(char)* tempstart = null;
        size_t templen = 0;
        const(char)* namestart = null;
        size_t namelen = 0; // !=0 if line continuation
        const(char)* textstart = null;
        size_t textlen = 0;
        while (p < pend)
        {
            // Skip to start of macro
            while (1)
            {
                if (p >= pend)
                    goto Ldone;
                switch (*p)
                {
                case ' ':
                case '\t':
                    p++;
                    continue;
                case '\r':
                case '\n':
                    p++;
                    goto Lcont;
                default:
                    if (isIdStart(p))
                        break;
                    if (namelen)
                        goto Ltext;
                    // continuation of prev macro
                    goto Lskipline;
                }
                break;
            }
            tempstart = p;
            while (1)
            {
                if (p >= pend)
                    goto Ldone;
                if (!isIdTail(p))
                    break;
                p += utfStride(p);
            }
            templen = p - tempstart;
            while (1)
            {
                if (p >= pend)
                    goto Ldone;
                if (!(*p == ' ' || *p == '\t'))
                    break;
                p++;
            }
            if (*p != '=')
            {
                if (namelen)
                    goto Ltext;
                // continuation of prev macro
                goto Lskipline;
            }
            p++;
            if (p >= pend)
                goto Ldone;
            if (namelen)
            {
                // Output existing macro
            L1:
                //printf("macro '%.*s' = '%.*s'\n", namelen, namestart, textlen, textstart);
                if (icmp("ESCAPES", namestart, namelen) == 0)
                    parseEscapes(pescapetable, textstart, textlen);
                else
                    Macro.define(pmacrotable, namestart, namelen, textstart, textlen);
                namelen = 0;
                if (p >= pend)
                    break;
            }
            namestart = tempstart;
            namelen = templen;
            while (p < pend && (*p == ' ' || *p == '\t'))
                p++;
            textstart = p;
            Ltext: while (p < pend && *p != '\r' && *p != '\n')
                p++;
            textlen = p - textstart;
            p++;
            //printf("p = %p, pend = %p\n", p, pend);
        Lcont:
            continue;
        Lskipline:
            // Ignore this line
            while (p < pend && *p != '\r' && *p != '\n')
                p++;
        }
    Ldone:
        if (namelen)
            goto L1;
        // write out last one
    }

    /**************************************
     * Parse escapes of the form:
     *      /c/string/
     * where c is a single character.
     * Multiple escapes can be separated
     * by whitespace and/or commas.
     */
    extern (C++) static void parseEscapes(Escape** pescapetable, const(char)* textstart, size_t textlen)
    {
        Escape* escapetable = *pescapetable;
        if (!escapetable)
        {
            escapetable = new Escape();
            memset(escapetable, 0, (Escape).sizeof);
            *pescapetable = escapetable;
        }
        //printf("parseEscapes('%.*s') pescapetable = %p\n", textlen, textstart, pescapetable);
        const(char)* p = textstart;
        const(char)* pend = p + textlen;
        while (1)
        {
            while (1)
            {
                if (p + 4 >= pend)
                    return;
                if (!(*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n' || *p == ','))
                    break;
                p++;
            }
            if (p[0] != '/' || p[2] != '/')
                return;
            char c = p[1];
            p += 3;
            const(char)* start = p;
            while (1)
            {
                if (p >= pend)
                    return;
                if (*p == '/')
                    break;
                p++;
            }
            size_t len = p - start;
            char* s = cast(char*)memcpy(mem.xmalloc(len + 1), start, len);
            s[len] = 0;
            escapetable.strings[c] = s;
            //printf("\t%c = '%s'\n", c, s);
            p++;
        }
    }

    /*****************************************
     * Parse next paragraph out of *pcomment.
     * Update *pcomment to point past paragraph.
     * Returns NULL if no more paragraphs.
     * If paragraph ends in 'identifier:',
     * then (*pcomment)[0 .. idlen] is the identifier.
     */
    extern (C++) void parseSections(const(char)* comment)
    {
        const(char)* p;
        const(char)* pstart;
        const(char)* pend;
        const(char)* idstart = null; // dead-store to prevent spurious warning
        size_t idlen;
        const(char)* name = null;
        size_t namelen = 0;
        //printf("parseSections('%s')\n", comment);
        p = comment;
        while (*p)
        {
            const(char)* pstart0 = p;
            p = skipwhitespace(p);
            pstart = p;
            pend = p;
            /* Find end of section, which is ended by one of:
             *      'identifier:' (but not inside a code section)
             *      '\0'
             */
            idlen = 0;
            int inCode = 0;
            while (1)
            {
                // Check for start/end of a code section
                if (*p == '-')
                {
                    if (!inCode)
                    {
                        // restore leading indentation
                        while (pstart0 < pstart && isIndentWS(pstart - 1))
                            --pstart;
                    }
                    int numdash = 0;
                    while (*p == '-')
                    {
                        ++numdash;
                        p++;
                    }
                    // BUG: handle UTF PS and LS too
                    if ((!*p || *p == '\r' || *p == '\n') && numdash >= 3)
                        inCode ^= 1;
                    pend = p;
                }
                if (!inCode && isIdStart(p))
                {
                    const(char)* q = p + utfStride(p);
                    while (isIdTail(q))
                        q += utfStride(q);
                    if (*q == ':') // identifier: ends it
                    {
                        idlen = q - p;
                        idstart = p;
                        for (pend = p; pend > pstart; pend--)
                        {
                            if (pend[-1] == '\n')
                                break;
                        }
                        p = q + 1;
                        break;
                    }
                }
                while (1)
                {
                    if (!*p)
                        goto L1;
                    if (*p == '\n')
                    {
                        p++;
                        if (*p == '\n' && !summary && !namelen && !inCode)
                        {
                            pend = p;
                            p++;
                            goto L1;
                        }
                        break;
                    }
                    p++;
                    pend = p;
                }
                p = skipwhitespace(p);
            }
        L1:
            if (namelen || pstart < pend)
            {
                Section s;
                if (icmp("Params", name, namelen) == 0)
                    s = new ParamSection();
                else if (icmp("Macros", name, namelen) == 0)
                    s = new MacroSection();
                else
                    s = new Section();
                s.name = name;
                s.namelen = namelen;
                s._body = pstart;
                s.bodylen = pend - pstart;
                s.nooutput = 0;
                //printf("Section: '%.*s' = '%.*s'\n", s->namelen, s->name, s->bodylen, s->body);
                sections.push(s);
                if (!summary && !namelen)
                    summary = s;
            }
            if (idlen)
            {
                name = idstart;
                namelen = idlen;
            }
            else
            {
                name = null;
                namelen = 0;
                if (!*p)
                    break;
            }
        }
    }

    extern (C++) void writeSections(Scope* sc, Dsymbol s, OutBuffer* buf)
    {
        //printf("DocComment::writeSections()\n");
        if (sections.dim || s.ddocUnittest)
        {
            buf.writestring("$(DDOC_SECTIONS ");
            for (size_t i = 0; i < sections.dim; i++)
            {
                Section sec = sections[i];
                if (sec.nooutput)
                    continue;
                //printf("Section: '%.*s' = '%.*s'\n", sec->namelen, sec->name, sec->bodylen, sec->body);
                if (sec.namelen || i)
                    sec.write(&this, sc, s, buf);
                else
                {
                    buf.writestring("$(DDOC_SUMMARY ");
                    size_t o = buf.offset;
                    buf.write(sec._body, sec.bodylen);
                    escapeStrayParenthesis(buf, o, s);
                    highlightText(sc, s, buf, o);
                    buf.writestring(")\n");
                }
            }
            if (s.ddocUnittest)
                emitUnittestComment(sc, s, buf.offset);
            sc.lastoffset2 = buf.offset;
            buf.writestring(")\n");
        }
        else
        {
            buf.writestring("$(DDOC_BLANKLINE)\n");
        }
    }
}

/******************************************
 * Compare 0-terminated string with length terminated string.
 * Return < 0, ==0, > 0
 */
extern (C++) int cmp(const(char)* stringz, const(void)* s, size_t slen)
{
    size_t len1 = strlen(stringz);
    if (len1 != slen)
        return cast(int)(len1 - slen);
    return memcmp(stringz, s, slen);
}

extern (C++) int icmp(const(char)* stringz, const(void)* s, size_t slen)
{
    size_t len1 = strlen(stringz);
    if (len1 != slen)
        return cast(int)(len1 - slen);
    return Port.memicmp(stringz, cast(char*)s, slen);
}

/*****************************************
 * Return true if comment consists entirely of "ditto".
 */
extern (C++) bool isDitto(const(char)* comment)
{
    if (comment)
    {
        const(char)* p = skipwhitespace(comment);
        if (Port.memicmp(cast(const(char)*)p, "ditto", 5) == 0 && *skipwhitespace(p + 5) == 0)
            return true;
    }
    return false;
}

/**********************************************
 * Skip white space.
 */
extern (C++) const(char)* skipwhitespace(const(char)* p)
{
    for (; 1; p++)
    {
        switch (*p)
        {
        case ' ':
        case '\t':
        case '\n':
            continue;
        default:
            break;
        }
        break;
    }
    return p;
}

/************************************************
 * Scan forward to one of:
 *      start of identifier
 *      beginning of next line
 *      end of buf
 */
extern (C++) size_t skiptoident(OutBuffer* buf, size_t i)
{
    while (i < buf.offset)
    {
        dchar_t c;
        size_t oi = i;
        if (utf_decodeChar(cast(char*)buf.data, buf.offset, &i, &c))
        {
            /* Ignore UTF errors, but still consume input
             */
            break;
        }
        if (c >= 0x80)
        {
            if (!isUniAlpha(c))
                continue;
        }
        else if (!(isalpha(c) || c == '_' || c == '\n'))
            continue;
        i = oi;
        break;
    }
    return i;
}

/************************************************
 * Scan forward past end of identifier.
 */
extern (C++) size_t skippastident(OutBuffer* buf, size_t i)
{
    while (i < buf.offset)
    {
        dchar_t c;
        size_t oi = i;
        if (utf_decodeChar(cast(char*)buf.data, buf.offset, &i, &c))
        {
            /* Ignore UTF errors, but still consume input
             */
            break;
        }
        if (c >= 0x80)
        {
            if (isUniAlpha(c))
                continue;
        }
        else if (isalnum(c) || c == '_')
            continue;
        i = oi;
        break;
    }
    return i;
}

/************************************************
 * Scan forward past URL starting at i.
 * We don't want to highlight parts of a URL.
 * Returns:
 *      i if not a URL
 *      index just past it if it is a URL
 */
extern (C++) size_t skippastURL(OutBuffer* buf, size_t i)
{
    size_t length = buf.offset - i;
    char* p = cast(char*)&buf.data[i];
    size_t j;
    uint sawdot = 0;
    if (length > 7 && Port.memicmp(cast(char*)p, "http://", 7) == 0)
    {
        j = 7;
    }
    else if (length > 8 && Port.memicmp(cast(char*)p, "https://", 8) == 0)
    {
        j = 8;
    }
    else
        goto Lno;
    for (; j < length; j++)
    {
        char c = p[j];
        if (isalnum(c))
            continue;
        if (c == '-' || c == '_' || c == '?' || c == '=' || c == '%' || c == '&' || c == '/' || c == '+' || c == '#' || c == '~')
            continue;
        if (c == '.')
        {
            sawdot = 1;
            continue;
        }
        break;
    }
    if (sawdot)
        return i + j;
Lno:
    return i;
}

/****************************************************
 */
extern (C++) bool isKeyword(char* p, size_t len)
{
    static __gshared const(char)** table = ["true", "false", "null", null];
    for (int i = 0; table[i]; i++)
    {
        if (cmp(table[i], p, len) == 0)
            return true;
    }
    return false;
}

/****************************************************
 */
extern (C++) TypeFunction isTypeFunction(Dsymbol s)
{
    FuncDeclaration f = s.isFuncDeclaration();
    /* Check whether s refers to an eponymous function template.
     */
    if (f is null && s.isTemplateDeclaration() && s.isTemplateDeclaration().onemember)
    {
        f = s.isTemplateDeclaration().onemember.isFuncDeclaration();
    }
    /* f->type may be NULL for template members.
     */
    if (f && f.type)
    {
        TypeFunction tf;
        if (f.originalType)
        {
            tf = cast(TypeFunction)f.originalType;
        }
        else
            tf = cast(TypeFunction)f.type;
        return tf;
    }
    return null;
}

/****************************************************
 */
extern (C++) Parameter isFunctionParameter(Dsymbol s, const(char)* p, size_t len)
{
    TypeFunction tf = isTypeFunction(s);
    if (tf && tf.parameters)
    {
        for (size_t k = 0; k < tf.parameters.dim; k++)
        {
            Parameter fparam = (*tf.parameters)[k];
            if (fparam.ident && cmp(fparam.ident.toChars(), p, len) == 0)
            {
                return fparam;
            }
        }
    }
    return null;
}

/****************************************************
 */
extern (C++) TemplateParameter isTemplateParameter(Dsymbol s, const(char)* p, size_t len)
{
    TemplateDeclaration td = s.isTemplateDeclaration();
    if (td && td.origParameters)
    {
        for (size_t k = 0; k < td.origParameters.dim; k++)
        {
            TemplateParameter tp = (*td.origParameters)[k];
            if (tp.ident && cmp(tp.ident.toChars(), p, len) == 0)
            {
                return tp;
            }
        }
    }
    return null;
}

/** Return true if str is a reserved symbol name that starts with a double underscore. */
extern (C++) bool isReservedName(char* str, size_t len)
{
    static __gshared const(char)** table = ["__ctor", "__dtor", "__postblit", "__invariant", "__unitTest", "__require", "__ensure", "__dollar", "__ctfe", "__withSym", "__result", "__returnLabel", "__vptr", "__monitor", "__gate", "__xopEquals", "__xopCmp", "__LINE__", "__FILE__", "__MODULE__", "__FUNCTION__", "__PRETTY_FUNCTION__", "__DATE__", "__TIME__", "__TIMESTAMP__", "__VENDOR__", "__VERSION__", "__EOF__", "__LOCAL_SIZE", "___tls_get_addr", "__entrypoint", "__va_argsave_t", "__va_argsave", null];
    for (int i = 0; table[i]; i++)
    {
        if (cmp(table[i], str, len) == 0)
            return true;
    }
    return false;
}

/**************************************************
 * Highlight text section.
 */
extern (C++) void highlightText(Scope* sc, Dsymbol s, OutBuffer* buf, size_t offset)
{
    //printf("highlightText()\n");
    const(char)* sid = s.ident.toChars();
    FuncDeclaration f = s.isFuncDeclaration();
    char* p;
    const(char)* se;
    int leadingBlank = 1;
    int inCode = 0;
    int inBacktick = 0;
    //int inComment = 0;                  // in <!-- ... --> comment
    size_t iCodeStart = 0; // start of code section
    size_t codeIndent = 0;
    size_t iLineStart = offset;
    for (size_t i = offset; i < buf.offset; i++)
    {
        char c = buf.data[i];
    Lcont:
        switch (c)
        {
        case ' ':
        case '\t':
            break;
        case '\n':
            if (inBacktick)
            {
                // `inline code` is only valid if contained on a single line
                // otherwise, the backticks should be output literally.
                //
                // This lets things like `output from the linker' display
                // unmolested while keeping the feature consistent with GitHub.
                inBacktick = false;
                inCode = false; // the backtick also assumes we're in code
                // Nothing else is necessary since the DDOC_BACKQUOTED macro is
                // inserted lazily at the close quote, meaning the rest of the
                // text is already OK.
            }
            if (!sc._module.isDocFile && !inCode && i == iLineStart && i + 1 < buf.offset) // if "\n\n"
            {
                static __gshared const(char)* blankline = "$(DDOC_BLANKLINE)\n";
                i = buf.insert(i, blankline, strlen(blankline));
            }
            leadingBlank = 1;
            iLineStart = i + 1;
            break;
        case '<':
            leadingBlank = 0;
            if (inCode)
                break;
            p = cast(char*)&buf.data[i];
            se = sc._module.escapetable.escapeChar('<');
            if (se && strcmp(se, "&lt;") == 0)
            {
                // Generating HTML
                // Skip over comments
                if (p[1] == '!' && p[2] == '-' && p[3] == '-')
                {
                    size_t j = i + 4;
                    p += 4;
                    while (1)
                    {
                        if (j == buf.offset)
                            goto L1;
                        if (p[0] == '-' && p[1] == '-' && p[2] == '>')
                        {
                            i = j + 2; // place on closing '>'
                            break;
                        }
                        j++;
                        p++;
                    }
                    break;
                }
                // Skip over HTML tag
                if (isalpha(p[1]) || (p[1] == '/' && isalpha(p[2])))
                {
                    size_t j = i + 2;
                    p += 2;
                    while (1)
                    {
                        if (j == buf.offset)
                            break;
                        if (p[0] == '>')
                        {
                            i = j; // place on closing '>'
                            break;
                        }
                        j++;
                        p++;
                    }
                    break;
                }
            }
        L1:
            // Replace '<' with '&lt;' character entity
            if (se)
            {
                size_t len = strlen(se);
                buf.remove(i, 1);
                i = buf.insert(i, se, len);
                i--; // point to ';'
            }
            break;
        case '>':
            leadingBlank = 0;
            if (inCode)
                break;
            // Replace '>' with '&gt;' character entity
            se = sc._module.escapetable.escapeChar('>');
            if (se)
            {
                size_t len = strlen(se);
                buf.remove(i, 1);
                i = buf.insert(i, se, len);
                i--; // point to ';'
            }
            break;
        case '&':
            leadingBlank = 0;
            if (inCode)
                break;
            p = cast(char*)&buf.data[i];
            if (p[1] == '#' || isalpha(p[1]))
                break;
            // already a character entity
            // Replace '&' with '&amp;' character entity
            se = sc._module.escapetable.escapeChar('&');
            if (se)
            {
                size_t len = strlen(se);
                buf.remove(i, 1);
                i = buf.insert(i, se, len);
                i--; // point to ';'
            }
            break;
        case '`':
            
            {
                if (inBacktick)
                {
                    inBacktick = 0;
                    inCode = 0;
                    OutBuffer codebuf;
                    codebuf.write(buf.data + iCodeStart + 1, i - (iCodeStart + 1));
                    // escape the contents, but do not perform highlighting except for DDOC_PSYMBOL
                    highlightCode(sc, s, &codebuf, 0, false);
                    buf.remove(iCodeStart, i - iCodeStart + 1); // also trimming off the current `
                    static __gshared const(char)* pre = "$(DDOC_BACKQUOTED ";
                    i = buf.insert(iCodeStart, pre, strlen(pre));
                    i = buf.insert(i, cast(char*)codebuf.data, codebuf.offset);
                    i = buf.insert(i, cast(char*)")", 1);
                    i--; // point to the ending ) so when the for loop does i++, it will see the next character
                    break;
                }
                if (inCode)
                    break;
                inCode = 1;
                inBacktick = 1;
                codeIndent = 0; // inline code is not indented
                // All we do here is set the code flags and record
                // the location. The macro will be inserted lazily
                // so we can easily cancel the inBacktick if we come
                // across a newline character.
                iCodeStart = i;
                break;
            }
            case '-':
                /* A line beginning with --- delimits a code section.
             * inCode tells us if it is start or end of a code section.
             */
                if (leadingBlank)
                {
                    size_t istart = i;
                    size_t eollen = 0;
                    leadingBlank = 0;
                    while (1)
                    {
                        ++i;
                        if (i >= buf.offset)
                            break;
                        c = buf.data[i];
                        if (c == '\n')
                        {
                            eollen = 1;
                            break;
                        }
                        if (c == '\r')
                        {
                            eollen = 1;
                            if (i + 1 >= buf.offset)
                                break;
                            if (buf.data[i + 1] == '\n')
                            {
                                eollen = 2;
                                break;
                            }
                        }
                        // BUG: handle UTF PS and LS too
                        if (c != '-')
                            goto Lcont;
                    }
                    if (i - istart < 3)
                        goto Lcont;
                    // We have the start/end of a code section
                    // Remove the entire --- line, including blanks and \n
                    buf.remove(iLineStart, i - iLineStart + eollen);
                    i = iLineStart;
                    if (inCode && (i <= iCodeStart))
                    {
                        // Empty code section, just remove it completely.
                        inCode = 0;
                        break;
                    }
                    if (inCode)
                    {
                        inCode = 0;
                        // The code section is from iCodeStart to i
                        OutBuffer codebuf;
                        codebuf.write(buf.data + iCodeStart, i - iCodeStart);
                        codebuf.writeByte(0);
                        // Remove leading indentations from all lines
                        bool lineStart = true;
                        char* endp = cast(char*)codebuf.data + codebuf.offset;
                        for (p = cast(char*)codebuf.data; p < endp;)
                        {
                            if (lineStart)
                            {
                                size_t j = codeIndent;
                                char* q = p;
                                while (j-- > 0 && q < endp && isIndentWS(q))
                                    ++q;
                                codebuf.remove(p - cast(char*)codebuf.data, q - p);
                                assert(cast(char*)codebuf.data <= p);
                                assert(p < cast(char*)codebuf.data + codebuf.offset);
                                lineStart = false;
                                endp = cast(char*)codebuf.data + codebuf.offset; // update
                                continue;
                            }
                            if (*p == '\n')
                                lineStart = true;
                            ++p;
                        }
                        highlightCode2(sc, s, &codebuf, 0);
                        buf.remove(iCodeStart, i - iCodeStart);
                        i = buf.insert(iCodeStart, codebuf.data, codebuf.offset);
                        i = buf.insert(i, cast(const(char)*)")\n", 2);
                        i -= 2; // in next loop, c should be '\n'
                    }
                    else
                    {
                        static __gshared const(char)* d_code = "$(D_CODE ";
                        inCode = 1;
                        codeIndent = istart - iLineStart; // save indent count
                        i = buf.insert(i, d_code, strlen(d_code));
                        iCodeStart = i;
                        i--; // place i on >
                        leadingBlank = true;
                    }
                }
                break;
        default:
            leadingBlank = 0;
            if (!sc._module.isDocFile && !inCode && isIdStart(cast(char*)&buf.data[i]))
            {
                size_t j = skippastident(buf, i);
                if (j > i)
                {
                    size_t k = skippastURL(buf, i);
                    if (k > i)
                    {
                        i = k - 1;
                        break;
                    }
                    // leading '_' means no highlight unless it's a reserved symbol name
                    if (buf.data[i] == '_' && (i == 0 || !isdigit(buf.data[i - 1])) && (i == buf.size - 1 || !isReservedName(cast(char*)(buf.data + i), j - i)))
                    {
                        buf.remove(i, 1);
                        i = j - 1;
                    }
                    else
                    {
                        if (cmp(sid, buf.data + i, j - i) == 0)
                        {
                            i = buf.bracket(i, "$(DDOC_PSYMBOL ", j, ")") - 1;
                            break;
                        }
                        else if (isKeyword(cast(char*)buf.data + i, j - i))
                        {
                            i = buf.bracket(i, "$(DDOC_KEYWORD ", j, ")") - 1;
                            break;
                        }
                        else
                        {
                            char* start = cast(char*)buf.data + i;
                            size_t end = j - i;
                            if (f && (isFunctionParameter(f, start, end) || isCVariadicParameter(f, start, end)))
                            {
                                //printf("highlighting arg '%s', i = %d, j = %d\n", arg->ident->toChars(), i, j);
                                i = buf.bracket(i, "$(DDOC_PARAM ", j, ")") - 1;
                                break;
                            }
                        }
                        i = j - 1;
                    }
                }
            }
            break;
        }
    }
    if (inCode)
        s.error("unmatched --- in DDoc comment");
}

/**************************************************
 * Highlight code for DDOC section.
 */
extern (C++) void highlightCode(Scope* sc, Dsymbol s, OutBuffer* buf, size_t offset, bool anchor = true)
{
    if (anchor)
    {
        OutBuffer ancbuf;
        emitAnchor(&ancbuf, s, sc);
        buf.insert(offset, cast(char*)ancbuf.data, ancbuf.offset);
        offset += ancbuf.offset;
    }
    char* sid = s.ident.toChars();
    FuncDeclaration f = s.isFuncDeclaration();
    //printf("highlightCode(s = '%s', kind = %s)\n", sid, s->kind());
    for (size_t i = offset; i < buf.offset; i++)
    {
        char c = buf.data[i];
        const(char)* se;
        se = sc._module.escapetable.escapeChar(c);
        if (se)
        {
            size_t len = strlen(se);
            buf.remove(i, 1);
            i = buf.insert(i, se, len);
            i--; // point to ';'
        }
        else if (isIdStart(cast(char*)&buf.data[i]))
        {
            size_t j = skippastident(buf, i);
            if (j > i)
            {
                if (cmp(sid, buf.data + i, j - i) == 0)
                {
                    i = buf.bracket(i, "$(DDOC_PSYMBOL ", j, ")") - 1;
                    continue;
                }
                else if (f)
                {
                    char* start = cast(char*)buf.data + i;
                    size_t end = j - i;
                    if (isFunctionParameter(f, start, end) || isCVariadicParameter(f, start, end))
                    {
                        //printf("highlighting arg '%s', i = %d, j = %d\n", arg->ident->toChars(), i, j);
                        i = buf.bracket(i, "$(DDOC_PARAM ", j, ")") - 1;
                        continue;
                    }
                }
                i = j - 1;
            }
        }
    }
}

/****************************************
 */
extern (C++) void highlightCode3(Scope* sc, OutBuffer* buf, const(char)* p, const(char)* pend)
{
    for (; p < pend; p++)
    {
        const(char)* s = sc._module.escapetable.escapeChar(*p);
        if (s)
            buf.writestring(s);
        else
            buf.writeByte(*p);
    }
}

/**************************************************
 * Highlight code for CODE section.
 */
extern (C++) void highlightCode2(Scope* sc, Dsymbol s, OutBuffer* buf, size_t offset)
{
    const(char)* sid = s.ident.toChars();
    FuncDeclaration f = s.isFuncDeclaration();
    uint errorsave = global.errors;
    scope Lexer lex = new Lexer(null, cast(char*)buf.data, 0, buf.offset - 1, 0, 1);
    Token tok;
    OutBuffer res;
    const(char)* lastp = cast(char*)buf.data;
    const(char)* highlight;
    if (s.isModule() && (cast(Module)s).isDocFile)
        sid = "";
    //printf("highlightCode2('%.*s')\n", buf->offset - 1, buf->data);
    res.reserve(buf.offset);
    while (1)
    {
        lex.scan(&tok);
        highlightCode3(sc, &res, lastp, tok.ptr);
        highlight = null;
        switch (tok.value)
        {
        case TOKidentifier:
            if (!sc)
                break;
            if (cmp(sid, tok.ptr, lex.p - tok.ptr) == 0)
            {
                highlight = "$(D_PSYMBOL ";
                break;
            }
            else if (f)
            {
                size_t end = lex.p - tok.ptr;
                if (isFunctionParameter(f, tok.ptr, end) || isCVariadicParameter(f, tok.ptr, end))
                {
                    //printf("highlighting arg '%s', i = %d, j = %d\n", arg->ident->toChars(), i, j);
                    highlight = "$(D_PARAM ";
                    break;
                }
            }
            break;
        case TOKcomment:
            highlight = "$(D_COMMENT ";
            break;
        case TOKstring:
            highlight = "$(D_STRING ";
            break;
        default:
            if (tok.isKeyword())
                highlight = "$(D_KEYWORD ";
            break;
        }
        if (highlight)
        {
            res.writestring(highlight);
            size_t o = res.offset;
            highlightCode3(sc, &res, tok.ptr, lex.p);
            if (tok.value == TOKcomment || tok.value == TOKstring)
                escapeDdocString(&res, o); // Bugzilla 7656, 7715, and 10519
            res.writeByte(')');
        }
        else
            highlightCode3(sc, &res, tok.ptr, lex.p);
        if (tok.value == TOKeof)
            break;
        lastp = lex.p;
    }
    buf.setsize(offset);
    buf.write(&res);
    global.errors = errorsave;
}

/****************************************
 * Determine if p points to the start of a "..." parameter identifier.
 */
extern (C++) bool isCVariadicArg(const(char)* p, size_t len)
{
    return len >= 3 && cmp("...", p, 3) == 0;
}

/****************************************
 * Determine if p points to the start of an identifier.
 */
extern (C++) bool isIdStart(const(char)* p)
{
    uint c = *p;
    if (isalpha(c) || c == '_')
        return true;
    if (c >= 0x80)
    {
        size_t i = 0;
        if (utf_decodeChar(p, 4, &i, &c))
            return false; // ignore errors
        if (isUniAlpha(c))
            return true;
    }
    return false;
}

/****************************************
 * Determine if p points to the rest of an identifier.
 */
extern (C++) bool isIdTail(const(char)* p)
{
    uint c = *p;
    if (isalnum(c) || c == '_')
        return true;
    if (c >= 0x80)
    {
        size_t i = 0;
        if (utf_decodeChar(p, 4, &i, &c))
            return false; // ignore errors
        if (isUniAlpha(c))
            return true;
    }
    return false;
}

/****************************************
 * Determine if p points to the indentation space.
 */
extern (C++) bool isIndentWS(const(char)* p)
{
    return (*p == ' ') || (*p == '\t');
}

/*****************************************
 * Return number of bytes in UTF character.
 */
extern (C++) int utfStride(const(char)* p)
{
    uint c = *p;
    if (c < 0x80)
        return 1;
    size_t i = 0;
    utf_decodeChar(p, 4, &i, &c); // ignore errors, but still consume input
    return cast(int)i;
}
