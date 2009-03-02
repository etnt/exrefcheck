%%% -*- mode:erlang -*-
%%%
%%% This is the application resource file (.app file) for 
%%% the xrefcheck, application.
%%%
{application, exrefcheck,
  [{description, "A front end command for xref."},
   {vsn, "0.9.0"},
   {modules, [exrefcheck, exrefcheck_app]},
   {registered, []},
   {applications, [kernel, stdlib]},
   {mod, {exrefcheck_app, []}}
  ]
}.

