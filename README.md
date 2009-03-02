*exrefcheck* is a front end to xref.

It can either be called as a shell command or as an
embedded Erlang function. Warnings are printed to the
terminal. It is possible to suppress certain warnings
as will as explicitly mark functions to be ignored by
*exrefcheck*.

Here is an example of how to call exrefcheck

    ./exrefcheck.sh -exrefcheck ebin_dirs '"/home/tobbe/git/bon/ebin:/home/tobbe/git/nitrogen/ebin"' 

