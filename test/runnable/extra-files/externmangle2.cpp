
struct Test32NS1
{
	template<class X>
	struct Foo 
	{
		X *v;
	};

	template<class X>
	struct Bar 
	{
		X *v;
	};

};

struct Test32NS2
{
	template<class X>
	struct Foo 
	{
		X *v;
	};
};

template <template <class X> class Y, template <class X> class Z>
struct Test32
{
	Y<int>* field;
};


void test32a(Test32<Test32NS1::Foo, Test32NS1::Foo> arg)
{
}

void test32b(Test32<Test32NS1::Foo, Test32NS1::Bar> arg)
{
}

void test32c(Test32<Test32NS1::Foo, Test32NS2::Foo> arg)
{
}

void test32d(Test32<Test32NS1::Foo, Test32NS2::Foo> arg1, Test32<Test32NS2::Foo, Test32NS1::Foo> arg2)
{
}


class XXX
{
};
template <void (&Goo)(XXX*, XXX**), void (&Xoo)(XXX*, XXX**)>
struct Test33
{
};

void test33a(XXX*, XXX**){}

void test33(XXX*, Test33<test33a, test33a> arg, XXX*)
{
}

template <void (&Goo)(int)>
struct Test34
{
};

struct Test34A
{
    static void foo(int);
};

void Test34A::foo(int) {}
void test34(Test34<Test34A::foo> arg)
{
}


struct Test35
{
	Test35(int);
	~Test35();
};

Test35::Test35(int){}
Test35::~Test35(){}

int test36= 36;

template <int& XREF>
struct Test37
{
};

struct Test37A
{
    static int t38;
};

int Test37A::t38 = 42;

void test37(Test37<test36> arg)
{
}

void test38(Test37<Test37A::t38> arg)
{
}

struct Test39
{
	template <class X>
	struct T39A
	{
	};
};

struct T39A
{
};

void test39(Test39::T39A< ::T39A >)
{
}

#if 0 //only for g++ with -std=c++0x
    #ifdef __GNUG__
        template<class... VarArg> struct Test40
        {
        };

        void test40(Test40<int, double, void> arg)
        {
        }
    #endif
#endif
