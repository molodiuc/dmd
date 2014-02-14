
#include "module.h"
#include "declaration.h"
#include "aggregate.h"
#include "enum.h"
#include "attrib.h"
#include "template.h"
#include "statement.h"
#include "init.h"
#include "ctfe.h"
#include "lib.h"

// tocsym

Symbol *SymbolDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *Dsymbol::toSymbolX(const char *prefix, int sclass, TYPE *t, const char *suffix)
{
    assert(0);
    return NULL;
}

Symbol *Dsymbol::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *Dsymbol::toImport()
{
    assert(0);
    return NULL;
}

Symbol *Dsymbol::toImport(Symbol *sym)
{
    assert(0);
    return NULL;
}

Symbol *VarDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *ClassInfoDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *TypeInfoDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *TypeInfoClassDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *FuncAliasDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *FuncDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *FuncDeclaration::toThunkSymbol(int offset)
{
    assert(0);
    return NULL;
}

Symbol *ClassDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *InterfaceDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *Module::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *ClassDeclaration::toVtblSymbol()
{
    assert(0);
    return NULL;
}

Symbol *AggregateDeclaration::toInitializer()
{
    return NULL;
}

Symbol *TypedefDeclaration::toInitializer()
{
    return NULL;
}

Symbol *EnumDeclaration::toInitializer()
{
    return NULL;
}

Symbol *Module::toModuleAssert()
{
    return NULL;
}

Symbol *Module::toModuleUnittest()
{
    return NULL;
}

Symbol *Module::toModuleArray()
{
    return NULL;
}

Symbol *TypeAArray::aaGetSymbol(const char *func, int flags)
{
    assert(0);
    return NULL;
}

Symbol* StructLiteralExp::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol* ClassReferenceExp::toSymbol()
{
    assert(0);
    return NULL;
}

// todt

void ClassDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

void ClassDeclaration::toDt2(dt_t **pdt, ClassDeclaration *cd)
{
    assert(0);
}

void StructDeclaration::toDt(dt_t **pdt)
{
    assert(0);
}

dt_t **ClassReferenceExp::toInstanceDt(dt_t **pdt)
{
    assert(0);
    return NULL;
}

dt_t **ClassReferenceExp::toDt2(dt_t **pdt, ClassDeclaration *cd, Dts *dts)
{
    assert(0);
    return NULL;
}

// toobj

void Module::genmoduleinfo()
{
    assert(0);
}

void Dsymbol::toObjFile(int multiobj)
{
    assert(0);
}

void ClassDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

unsigned ClassDeclaration::baseVtblOffset(BaseClass *bc)
{
    assert(0);
    return 0;
}

void InterfaceDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void StructDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void VarDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void TypedefDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void EnumDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void TypeInfoDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void AttribDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void PragmaDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void TemplateInstance::toObjFile(int multiobj)
{
    assert(0);
}

void TemplateMixin::toObjFile(int multiobj)
{
    assert(0);
}

// glue

void obj_append(Dsymbol *s)
{
    assert(0);
}

void obj_write_deferred(Library *library)
{
}

void obj_start(char *srcfile)
{
}

void obj_end(Library *library, File *objfile)
{
}

bool obj_includelib(const char *name)
{
    assert(0);
    return false;
}

void obj_startaddress(Symbol *s)
{
    assert(0);
}

void Module::genobjfile(int multiobj)
{
}

void FuncDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

unsigned Type::totym()
{
    assert(0);
    return 0;
}

unsigned TypeFunction::totym()
{
    assert(0);
    return 0;
}

Symbol *Type::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *TypeClass::toSymbol()
{
    assert(0);
    return NULL;
}

elem *Module::toEfilename()
{
    assert(0);
    return NULL;
}

// msc

void backend_init()
{
}

void backend_term()
{
}

// typinf

Expression *Type::getInternalTypeInfo(Scope *sc)
{
    assert(0);
    return NULL;
}

Expression *Type::getTypeInfo(Scope *sc)
{
    Declaration *ti = new TypeInfoDeclaration(this, 1);
    Expression *e = new VarExp(Loc(), ti);
    e = e->addressOf(sc);
    e->type = ti->type;
    return e;
}

TypeInfoDeclaration *Type::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeTypedef::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypePointer::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeDArray::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeSArray::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeAArray::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeStruct::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeClass::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeVector::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeEnum::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeFunction::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeDelegate::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeTuple::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

int Type::builtinTypeInfo()
{
    assert(0);
    return 0;
}

int TypeBasic::builtinTypeInfo()
{
    assert(0);
    return 0;
}

int TypeDArray::builtinTypeInfo()
{
    assert(0);
    return 0;
}

int TypeClass::builtinTypeInfo()
{
    assert(0);
    return 0;
}

Expression *createTypeInfoArray(Scope *sc, Expression *exps[], size_t dim)
{
    /*
     * Pass a reference to the TypeInfo_Tuple corresponding to the types of the
     * arguments. Source compatibility is maintained by computing _arguments[]
     * at the start of the called function by offseting into the TypeInfo_Tuple
     * reference.
     */
    Parameters *args = new Parameters;
    args->setDim(dim);
    for (size_t i = 0; i < dim; i++)
    {   Parameter *arg = new Parameter(STCin, exps[i]->type, NULL, NULL);
        (*args)[i] = arg;
    }
    TypeTuple *tup = new TypeTuple(args);
    Expression *e = tup->getTypeInfo(sc);
    e = e->optimize(WANTvalue);
    assert(e->op == TOKsymoff);         // should be SymOffExp

    return e;
}

// tocvdebug

void TypedefDeclaration::toDebug()
{
    assert(0);
}

void EnumDeclaration::toDebug()
{
    assert(0);
}

void StructDeclaration::toDebug()
{
    assert(0);
}

void ClassDeclaration::toDebug()
{
    assert(0);
}

int Dsymbol::cvMember(unsigned char *p)
{
    assert(0);
    return 0;
}

int TypedefDeclaration::cvMember(unsigned char *p)
{
    assert(0);
    return 0;
}

int EnumDeclaration::cvMember(unsigned char *p)
{
    assert(0);
    return 0;
}

int FuncDeclaration::cvMember(unsigned char *p)
{
    assert(0);
    return 0;
}

int VarDeclaration::cvMember(unsigned char *p)
{
    assert(0);
    return 0;
}

// toir

void FuncDeclaration::buildClosure(IRState *irs)
{
    assert(0);
}

RET TypeFunction::retStyle()
{
    return RETregs;
}

// lib

Library *LibMSCoff_factory()
{
    assert(0);
    return NULL;
}

Library *LibOMF_factory()
{
    assert(0);
    return NULL;
}

Library *LibElf_factory()
{
    assert(0);
    return NULL;
}

Library *LibMach_factory()
{
    assert(0);
    return NULL;
}

Statement *AsmStatement::semantic(Scope *)
{
    assert(0);
    return NULL;
}
