*exrefcheck* is a front end to xref.

It can either be called as a shell command or as an
embedded Erlang function. Warnings are printed to the
terminal. It is possible to suppress certain warnings
at will by explicitly mark functions to be ignored by
*exrefcheck*.

Here is an example of how to call exrefcheck from the command line:

    ./exrefcheck.sh -exrefcheck ebin_dirs '"/home/tobbe/git/bon/ebin:/home/tobbe/git/nitrogen/ebin"' 

Another example, using a Makefile target looking like:

    xref:
            (export XREFCHECK_EBIN_DIRS=`pwd`/ebin; $(EXREFCHECK_DIR)/exrefcheck.sh)

then from the command line:

    make xref

To make *exrefcheck* ignore functions, add the *ignore_xref* module attribute, as:

    -ignore_xref([{foo,1}, {bar,2}, ...]).

This is especially useful when your module is exporting a library API.

