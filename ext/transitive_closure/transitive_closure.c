#include <ruby.h>

static VALUE all_paths_costs(VALUE module, VALUE rsize, VALUE distArray)
{
    int size = FIX2INT(rsize);
    int distArrayLen = size*size;

    // Create copy of distArray
    int cDistArray[distArrayLen];
    int i, k, j;
    for (i = 0; i < distArrayLen; i++) {
        cDistArray[i] = FIX2INT(rb_ary_entry(distArray, i));
    }

    for (k = 0; k < size; k++) {
        for (i = 0; i < size; i++) {
            for (j = 0; j < size; j++) {
                if (cDistArray[size*i+j] > cDistArray[size*i+k] + cDistArray[size*k+j]) {
                    cDistArray[size*i+j] = cDistArray[size*i+k] + cDistArray[size*k+j];
                }
            }
        }
    }

    // Copy cDistArray back into distArray
    for (i = 0; i < distArrayLen; i++) {
        rb_ary_store(distArray, i, INT2FIX(cDistArray[i]));
    }

    return distArray;
}

void Init_transitive_closure(void)
{
    VALUE cTransitiveClosure;

    cTransitiveClosure = rb_define_module("TransitiveClosure");

    rb_define_module_function(cTransitiveClosure, "all_paths_costs", all_paths_costs, 2);

    // rb_define_alloc_func(cMyMalloc, my_malloc_alloc);
    // rb_define_method(cMyMalloc, "initialize", my_malloc_init, 1);
    // rb_define_method(cMyMalloc, "free", my_malloc_release, 0);

    // create a ruby class instance
    // cMyClass = rb_define_class("MyClass", rb_cObject);
}
