
// Compiler implementation of the D programming language
// Copyright (c) 1999-2008 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

module lib;
extern(C++):

import root.root;
import root.stringtable;

struct ObjModule {};

struct ObjSymbol
{
    char *name;
    ObjModule *om;
};

import arraytypes;

alias ArrayBasex!ObjModule ObjModules;
alias ArrayBasex!ObjSymbol ObjSymbols;

struct Library
{
    File libfile;
    ObjModules objmodules;   // ObjModule[]
    ObjSymbols objsymbols;   // ObjSymbol[]

    StringTable tab;

    //Library();
    void setFilename(char *dir, char *filename);
    void addObject(const(char)* module_name, void *buf, size_t buflen);
    void addLibrary(void *buf, size_t buflen);
    void write();

  private:
    void addSymbol(ObjModule *om, char *name, int pickAny = 0);
    void scanObjModule(ObjModule *om);
    ushort numDictPages(uint padding);
    int FillDict(ubyte *bucketsP, ushort uNumPages);
    void WriteLibToBuffer(OutBuffer *libbuf);
};


