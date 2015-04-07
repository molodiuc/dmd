
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/toctype.c
 */

#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <time.h>
#include <assert.h>

#include "mars.h"
#include "module.h"
#include "mtype.h"
#include "declaration.h"
#include "enum.h"
#include "aggregate.h"
#include "id.h"
#include "aav.h"

#include "cc.h"
#include "global.h"
#include "type.h"

void slist_add(Symbol *s);
void slist_reset();
unsigned totym(Type *tx);

/***************************************
 * Convert from D type to C type.
 * This is done so C debug info can be generated.
 */

type *Type_toCtype(Type *t);

class ToCtypeVisitor : public Visitor
{
public:
    static AA *ctypeMap;

    type *ctype;
    ToCtypeVisitor() : ctype(NULL) {}

    void visit(Type *t)
    {
        ctype = type_fake(totym(t));
        ctype->Tcount++;
    }

    void visit(TypeSArray *t)
    {
        ctype = type_static_array(t->dim->toInteger(), Type_toCtype(t->next));
    }

    void visit(TypeDArray *t)
    {
        ctype = type_dyn_array(Type_toCtype(t->next));
        ctype->Tident = t->toPrettyChars(true);
    }

    void visit(TypeAArray *t)
    {
        ctype = type_assoc_array(Type_toCtype(t->index), Type_toCtype(t->next));
    }

    void visit(TypePointer *t)
    {
        //printf("TypePointer::toCtype() %s\n", t->toChars());
        ctype = type_pointer(Type_toCtype(t->next));
    }

    void visit(TypeFunction *t)
    {
        size_t nparams = Parameter::dim(t->parameters);

        type *tmp[10];
        type **ptypes = tmp;
        if (nparams > 10)
            ptypes = (type **)malloc(sizeof(type*) * nparams);

        for (size_t i = 0; i < nparams; i++)
        {
            Parameter *p = Parameter::getNth(t->parameters, i);
            type *tp = Type_toCtype(p->type);
            if (p->storageClass & (STCout | STCref))
                tp = type_allocn(TYnref, tp);
            else if (p->storageClass & STClazy)
            {
                // Mangle as delegate
                type *tf = type_function(TYnfunc, NULL, 0, false, tp);
                tp = type_delegate(tf);
            }
            ptypes[i] = tp;
        }

        ctype = type_function(totym(t), ptypes, nparams, t->varargs == 1, Type_toCtype(t->next));

        if (nparams > 10)
            free(ptypes);
    }

    void visit(TypeDelegate *t)
    {
        ctype = type_delegate(Type_toCtype(t->next));
    }

    void visit(TypeStruct *t)
    {
        //printf("TypeStruct::toCtype() '%s'\n", t->sym->toChars());
        if (t->mod == 0)
        {
            // Create the full ctype for this struct
            StructDeclaration *sym = t->sym;
            if (sym->ident == Id::__c_long_double)
            {
                ctype = type_fake(TYdouble);
                ctype->Tcount++;
                return;
            }
            ctype = type_struct_class(sym->toPrettyChars(true), sym->alignsize, sym->structsize,
                    sym->arg1type ? Type_toCtype(sym->arg1type) : NULL,
                    sym->arg2type ? Type_toCtype(sym->arg2type) : NULL,
                    sym->isUnionDeclaration() != 0,
                    false,
                    sym->isPOD() != 0);
            setCtype(t, ctype);

            /* Add in fields of the struct
             * (after setting ctype to avoid infinite recursion)
             */
            if (global.params.symdebug)
            {
                for (size_t i = 0; i < sym->fields.dim; i++)
                {
                    VarDeclaration *v = sym->fields[i];
                    symbol_struct_addField(ctype->Ttag, v->ident->toChars(), Type_toCtype(v->type), v->offset);
                }
            }
            return;
        }

        type *tmctype = Type_toCtype(t->mutableOf()->unSharedOf());

        ctype = type_alloc(tybasic(tmctype->Tty));
        ctype->Tcount++;
        if (ctype->Tty == TYstruct)
        {
            Symbol *s = tmctype->Ttag;
            ctype->Ttag = (Classsym *)s;            // structure tag name
        }
        // Add modifiers
        switch (t->mod)
        {
            case 0:
                assert(0);
                break;
            case MODconst:
            case MODwild:
            case MODwildconst:
                ctype->Tty |= mTYconst;
                break;
            case MODshared:
                ctype->Tty |= mTYshared;
                break;
            case MODshared | MODconst:
            case MODshared | MODwild:
            case MODshared | MODwildconst:
                ctype->Tty |= mTYshared | mTYconst;
                break;
            case MODimmutable:
                ctype->Tty |= mTYimmutable;
                break;
            default:
                assert(0);
        }

        //printf("t = %p, Tflags = x%x\n", ctype, ctype->Tflags);
    }

    void visit(TypeEnum *t)
    {
        //printf("TypeEnum::toCtype() '%s'\n", t->sym->toChars());
        if (t->mod == 0)
        {
        Lcreatetype:
            if (t->sym->memtype->toBasetype()->ty == Tint32)
            {
                ctype = type_enum(t->sym->toPrettyChars(true), Type_toCtype(t->sym->memtype));
            }
            else
            {
                ctype = Type_toCtype(t->sym->memtype);
            }
            return;
        }

        type *tmctype = Type_toCtype(t->mutableOf()->unSharedOf());

        if (tybasic(tmctype->Tty) != TYenum)
            goto Lcreatetype;

        Symbol *s = tmctype->Ttag;
        assert(s);
        ctype = type_alloc(TYenum);
        ctype->Ttag = (Classsym *)s;            // enum tag name
        ctype->Tcount++;
        ctype->Tnext = tmctype->Tnext;
        ctype->Tnext->Tcount++;
        // Add modifiers
        switch (t->mod)
        {
            case 0:
                assert(0);
                break;
            case MODconst:
            case MODwild:
            case MODwildconst:
                ctype->Tty |= mTYconst;
                break;
            case MODshared:
                ctype->Tty |= mTYshared;
                break;
            case MODshared | MODconst:
            case MODshared | MODwild:
            case MODshared | MODwildconst:
                ctype->Tty |= mTYshared | mTYconst;
                break;
            case MODimmutable:
                ctype->Tty |= mTYimmutable;
                break;
            default:
                assert(0);
        }

        //printf("t = %p, Tflags = x%x\n", t, t->Tflags);
    }

    void visit(TypeClass *t)
    {
        //printf("TypeClass::toCtype() %s\n", toChars());
        type *tc = type_struct_class(t->sym->toPrettyChars(true), t->sym->alignsize, t->sym->structsize,
                NULL,
                NULL,
                false,
                true,
                true);

        ctype = type_pointer(tc);
        setCtype(t, ctype);

        /* Add in fields of the class
         * (after setting ctype to avoid infinite recursion)
         */
        if (global.params.symdebug)
        {
            for (size_t i = 0; i < t->sym->fields.dim; i++)
            {
                VarDeclaration *v = t->sym->fields[i];
                symbol_struct_addField(tc->Ttag, v->ident->toChars(), Type_toCtype(v->type), v->offset);
            }
        }
    }

    static void setCtype(Type *t, type *ctype)
    {
        type **pctype = (type **)dmd_aaGet(&ctypeMap, (void *)t);
        *pctype = ctype;
    }

    static type *toCtype(Type *t)
    {
        type **ctype = (type **)dmd_aaGet(&ctypeMap, (void *)t);

        if (!*ctype)
        {
            ToCtypeVisitor v;
            t->accept(&v);
            *ctype = v.ctype;
        }
        return *ctype;
    }
};

AA *ToCtypeVisitor::ctypeMap = NULL;

type *Type_toCtype(Type *t)
{
    return ToCtypeVisitor::toCtype(t);
}
