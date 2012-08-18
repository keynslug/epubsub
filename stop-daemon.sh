#!/usr/bin/env escript
%% -*- erlang -*-
%%! -sname epubsubadm@`hostname` -cookie epubsub_cookie

main(_) ->
    Host = list_to_atom("epubsubsrv@" ++ net_adm:localhost()),
    io:format("Stopping daemon: "),
    Res = rpc:call(Host, init, stop, []),
    io:format("~p~n", [Res]).


