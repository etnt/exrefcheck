%%% -*- erlang-indent-level: 2 -*-
%%%-------------------------------------------------------------------
%%% Created  : 1 Maj 2008 by Torbjorn Tornkvist <tobbe@kreditor.se>
%%%            Modified the original code to suit Erlware and the 
%%%            general public. Also, added edoc documentation.
%%% 
%%% @doc exrefcheck is a front end to xref.
%%%      It can either be called as a shell command or as an
%%%      embedded Erlang function. Warnings are printed to the
%%%      terminal. It is possible to suppress certain warnings
%%%      as will as explicitly mark functions to be ignored by
%%%      <em>exrefcheck</em>.
%%%
%%% @type ebin_paths(). Paths leading to ebin dirs, separated by , or :
%%% @type options() = [opt()]
%%% @type opt() = yaws_out | test_fun | test_mods
%%%
%%% @end
%%% @author Daniel Luna and others
%%%-------------------------------------------------------------------
-module(exrefcheck).

-export([start/0
         ,test/3
        ]).

-import(lists, [member/2, foldr/3]).

-ignore_xref([{test,3}]).

-define(XREF, ?MODULE).

%%% --------------------------------------------------------------------
%%% @spec start() -> {ok, pid()}
%%% @doc Start exrefcheck.
%%%      This function will lookup ebin directories based on any of
%%%      possible environment variables or exrefcheck parameters. 
%%% @end
%%% --------------------------------------------------------------------
start() ->
  application:load(?MODULE),
  {ok, spawn(fun() -> test() end)}.


get_ebin_paths() -> 
  Edirs = get_param(ebin_dirs, "XREFCHECK_EBIN_DIRS"),
  foldr(fun(Dir, Acc) ->  filelib:wildcard(Dir++"/*/ebin")++Acc end,
        [], get_param(code_path_dirs, "XREFCHECK_LIB_DIRS")) ++ Edirs.

get_code_path() -> 
  CP1 = get_param(code_path, "XREFCHECK_CODE_PATH"),
  foldr(fun(Dir, Acc) ->  filelib:wildcard(Dir++"/*/ebin")++Acc end,
        [], get_param(code_path_dirs, "XREFCHECK_CODE_PATH_DIRS")) ++ CP1.

get_opts() -> 
  get_param(opts, "XREFCHECK_OPTS").


test() ->
    Opts      = get_opts(),
    EbinPaths = get_ebin_paths(),
    CodePaths = get_code_path(),
    test(EbinPaths, CodePaths, Opts).


%%% --------------------------------------------------------------------
%%% @spec test(Paths::ebin_paths(), Opts::options()) -> {ok, pid()}
%%% @doc Will run <em>xrefcheck</em> using the given input.
%%% @end
%%% --------------------------------------------------------------------
test(EbinPaths, CodePaths, Opts) ->
  try 
    error_logger:info_msg("EbinPaths=~p, CodePaths=~p~n", [EbinPaths, CodePaths]),
    [code:add_pathz(P) || P <- EbinPaths],
    start_xref(EbinPaths, CodePaths, Opts),
    {Exports, Mods} = exports_not_used(Opts),
    Locals          = locals_not_used(),
    Undef           = undefined_functions(),
    xref:stop(?XREF),
    case Exports ++ Mods ++ Locals ++ Undef of
      []   -> halt_0();
      List ->
        io:format("~s", [List]),
        halt_1()
    end
  catch
    _:_ ->         
      io:format("INTERNAL ERROR: ~p~n", [erlang:get_stacktrace()]),
      halt_1()
  end.

halt_0() ->
  %%halt(0).
  true.

halt_1() ->
  io:format("~nWARNING! Consider to fix the above errors or use:~n~n"
            "   -ignore_xref([{FuncName,Arity}, ...]). ~n"
            "~nin the affected modules.~n~n",
            []),
  halt(1).


start_xref(EbinPaths, CodePaths, _Opts) ->

  xref:start(?XREF),
  xref:set_library_path(?XREF, EbinPaths ++ CodePaths ++ code:get_path()),
  %% We print the warnings ourselves. Turn off xref printouts
  xref:set_default(?XREF, [{warnings,false},{verbose,false}]),

  [{ok,_} = xref:add_directory(?XREF, Dir) || Dir <- EbinPaths].


exports_not_used(Opts) ->
  {ok, UnusedExports0} = xref:analyze(?XREF, exports_not_used),

  UnusedExports1 = lists:foldl(fun(F,Acc) -> F(Acc) end, 
                               UnusedExports0,
                               [yaws_out(Opts),
                                test_fun(Opts),
                                test_mods(Opts)]),
  
  UnusedExports = filter_away_ignored(UnusedExports1),

  FormatUnused =
    [io_lib:format("Exported but unused: ~s\n",[format_mfa(MFA)])
     || MFA <- UnusedExports],

  %% Report unused modules
  FormatMods =
    [case [{M,F,A} || {F,A} <- M:module_info(exports)]
       -- [{M,module_info,0}, {M,module_info,1} | UnusedExports] of 
       [] -> io_lib:format("Unused module: ~w~n",[M]); 
       _ -> ""
     end || M <- lists:usort([M || {M,_,_} <- UnusedExports])],

  {FormatUnused, FormatMods}.

%%%
%%% Maybe suppress warnings for Yaws out/1 functions
%%%
yaws_out(Opts) -> 
  fun(UnusedExports) -> yaws_out(lists:member(yaws_out,Opts),UnusedExports) end.
  
yaws_out(true, UnusedExports) -> UnusedExports;
yaws_out(_, UnusedExports) ->
   [X || X <- UnusedExports,
         fun({_,out,1}) -> false; (_) -> true end(X)].

%%%
%%% Maybe suppress warnings for test/0 and test2/0 functions.
%%%
test_fun(Opts) -> 
  fun(UnusedExports) -> test_fun(lists:member(test_fun,Opts),UnusedExports) end.
  
test_fun(true, UnusedExports) -> UnusedExports;
test_fun(_, UnusedExports) ->
  [X || X <- UnusedExports,
        fun({_,test,0})  -> false;
           ({_,test2,0}) -> false;
           (_)           -> true end(X)].

%%%
%%% Maybe suppress warnings for test suite module functions.
%%%
test_mods(Opts) -> 
  fun(UnusedExports) -> test_mods(lists:member(test_mods,Opts),UnusedExports) end.
  
test_mods(true, UnusedExports) -> UnusedExports;
test_mods(_, UnusedExports) ->
  [X || X = {M,_,_} <- UnusedExports,
        case lists:reverse(atom_to_list(M)) of
          [$t,$s,$e,$t,$_|_] -> false; % _test.erl
          [$E,$T,$I,$U,$S|_] -> false; % SUITE.erl
          _ -> true
        end].

%%%
%%% Ignore behaviour functions, and explicitly marked functions
%%%
filter_away_ignored(UnusedExports) ->
  %% Functions can be ignored by using
  %% -ignore_xref([{F, A}, ...]).
  AttrIgnore =
    lists:flatten(
      lists:map(fun(M) ->
		    Attrs     = ks(attributes, M:module_info()),
		    Ignore    = ks(ignore_xref, Attrs),
		    Callbacks = [B:behaviour_info(callbacks) ++
				 case B of
				   gen_server -> [{start_link, 0}];
				   _ -> []
				 end ||
				  B <- ks(behaviour, Attrs)],
		    [{M, F, A} || {F, A} <- Ignore ++ lists:flatten(Callbacks)]
		end, lists:usort([M || {M, _, _} <- UnusedExports]))),

  [X || X <- UnusedExports, not(member(X, AttrIgnore))].


ks(Key, List) ->
  case lists:keysearch(Key, 1, List) of
    {value, {Key, Value}} -> Value;
    false -> []
  end.

locals_not_used() ->
  {ok,UnusedLocals0} = xref:analyze(?XREF, locals_not_used),
  UnusedLocals = filter_away_ignored(UnusedLocals0),

  [io_lib:format("Unused local function: ~s\n", [format_mfa(MFA)])
   || MFA <- UnusedLocals].


undefined_functions() ->
  {ok,Undefined0} = xref:analyze(?XREF, undefined_function_calls),
  Undefined1 = filter_away_ignored2(Undefined0),

  Undefined = [X || X={_,Func} <- Undefined1, 
                    Func /= {init,stop,1}],

  [io_lib:format("~s calls undefined ~s\n", [format_mfa(MFA1), format_mfa(MFA2)])
   || {MFA1,MFA2} <- Undefined].

%%%
%%% Ignore explicitly marked functions for undefined calls
%%%
filter_away_ignored2(UndefCallsFrom) ->
  %% Functions can also be ignored by using
  %% -ignore_xref([{M, F, A}, ...]).

  F = fun({{M,_,_}, UFA} = X, Acc) ->
          Attrs     = ks(attributes, M:module_info()),
          Ignore    = ks(ignore_xref, Attrs),
          case member(UFA, Ignore) of
            true  -> Acc;
            false -> [X|Acc]
          end
      end,

  lists:flatten(lists:foldl(F, [], UndefCallsFrom)).


format_mfa({M,F,A}) ->
  io_lib:format("~s:~s/~p", [M,F,A]).


%%%
%%% Specify multiple param values sparated with ':' or ' '.
%%%
get_param(Switch, Env) ->
  try
    {ok, Value} = application:get_env(?MODULE, Switch), 
    string:tokens(a2l(Value), ": ")
  catch
    _:_ ->
      case os:getenv(Env) of
        false  -> [];
        GetEnv -> string:tokens(a2l(GetEnv), ":,")
      end

  end.

a2l(A) when is_atom(A) -> atom_to_list(A);
a2l(L) when is_list(L) -> L.

  































