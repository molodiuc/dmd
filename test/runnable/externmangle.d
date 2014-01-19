// EXTRA_CPP_SOURCES: externmangle.cpp

version(Windows)
{
}
else
{
    extern(C++):

    struct Foo(X)
    {
        X* v;
    }


    struct Boo(X)
    {
        X* v;
    }


    void test1(Foo!int arg1);
    void test2(int* arg2, Boo!(int*) arg1);


    struct Test3(int X, int Y)
    {
    }

    void test3(Test3!(3,3) arg1);

    void test4(Foo!(int*) arg1, Boo!(int*) arg2, Boo!(int*) arg3, int*, Foo!(double));

    void test5(Foo!(int*) arg1, Boo!(int*) arg2, Boo!(int*) arg3);


    struct Goo
    {
        struct Foo(X)
        {
            X* v;
        }

        struct Boo(X)
        {
            struct Xoo(Y) 
            {
                Y* v;
            };
            X* v;
        }


        void test6(Foo!(Boo!(Foo!(void))) arg1);
        void test7(Boo!(void).Xoo!(int) arg1);
    }

    struct P1
    {
        struct Mem(T)
        {
        }
    }

    struct P2
    {
        struct Mem(T)
        {
        }
    }

    void test8(P1.Mem!int, P2.Mem!int);
    void test9(Foo!(int**), Foo!(int*), int**, int*);


    interface Test10
    {
        private final void test10();
        public final void test11();
        protected final void test12();
        public final void test13() const;

        private void test14();
        public void test15();
        protected void test16();   

        private static void test17();
        public static void test18();
        protected static void test19();
    };

    Test10 Test10Ctor();
    void Test10Dtor(ref Test10 ptr);

    struct Test20
    {
        __gshared:
        private extern int test20;
        protected extern int test21;
        public extern int test22;
    };


    int test23(Test10*, Test10, Test10**, const(Test10));
    void test24(int function(int,int));

    void test25(int[291][6][5]* arr);
    void test26(int[291][6][5] arr);

    void test27(int, ...);
    void test28(int);

    void test29(float);
    void test30(const float);

    void test31(shared(float)*);

    void main()
    {
        test1(Foo!int());
        test2(null, Boo!(int*)());
        test3(Test3!(3,3)());
        test4(Foo!(int*)(), Boo!(int*)(), Boo!(int*)(), null, Foo!(double)());
        test5(Foo!(int*)(), Boo!(int*)(), Boo!(int*)());
        Goo goo;
        goo.test6(Goo.Foo!(Goo.Boo!(Goo.Foo!(void)))());
        goo.test7(Goo.Boo!(void).Xoo!(int)());
        
        test8(P1.Mem!int(), P2.Mem!int());
        test9(Foo!(int**)(), Foo!(int*)(), null, null);
        
        auto t10 = Test10Ctor();
        scope(exit) Test10Dtor(t10);
        
        t10.test10();
        t10.test11();
        t10.test12();
        t10.test13();
        t10.test14();
        t10.test15();
        t10.test16();
        t10.test17();
        t10.test18();
        t10.test19();
        
        assert(Test20.test20 == 20);
        assert(Test20.test21 == 21);
        assert(Test20.test22 == 22);
        
        assert(test23(null, null, null, null) == 1);
        
        extern(C++) static int cb(int a, int b){return a+b;}
        
        test24(&cb);
        int[291][6][5] arr;
        
        test25(&arr);
        test26(arr);
        
        test27(3,4,5);
        test28(3);
        
        test29(3.14f);
        test30(3.14f);
        test31(null);
    }
}
