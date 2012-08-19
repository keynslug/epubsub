%
% PubSub channel server.
%

-module(epubsub_channel).
-behaviour(gen_server).

-include("epubsub_logger.hrl").

%% API
-export([
    start_link/1,
    start_link/2,
    stop/1,
    subscribe/1,
    unsubscribe/1,
    publish/2
]).

%% Callbacks
-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

%

start_link(Name, Options) ->
    gen_server:start_link(Name, ?MODULE, Options, []).

start_link(Options) ->
    gen_server:start_link(?MODULE, Options, []).

stop(Name) ->
    gen_server:call(Name, stop).

subscribe(Name) ->
    gen_server:call(Name, subscribe).

unsubscribe(Name) ->
    gen_server:call(Name, unsubscribe).

publish(Name, Payload) ->
    gen_server:call(Name, {publish, Payload}).

%

init(_Options) ->
    ?LOG_INFO("Starting pubsub channel..."),
    process_flag(trap_exit, true),
    {ok, create_state()}.

handle_call(subscribe, {Pid, _Tag}, State) ->
    ?LOG_DEBUG("Subscribe request from ~p", [Pid]),
    case do_subscribe(Pid, State) of
        {ok, FinalState} ->
            true = link(Pid),
            {reply, ok, FinalState};
        Error ->
            ?LOG_ERROR("Subscription failed due to ~p", [Error]),
            {reply, Error, State}
    end;

handle_call(unsubscribe, {Pid, _Tag}, State) ->
    ?LOG_DEBUG("Unsubscribe request from ~p", [Pid]),
    case do_unsubscribe(Pid, State) of
        {ok, FinalState} ->
            true = unlink(Pid),
            receive 
                {'EXIT', _Pid, _} -> ok
            after 0 ->
                ok
            end,
            {reply, ok, FinalState};
        Error ->
            ?LOG_ERROR("Unsubscription failed due to ~p", [Error]),
            {reply, Error, State}
    end;

handle_call({publish, Payload}, From = {Pid, _Tag}, State) ->
    ?LOG_DEBUG("Publish request from ~p", [Pid]),
    spawn(fun () -> gen_server:reply(From, do_publish(Pid, Payload, State)) end),
    {noreply, State};

handle_call(stop, _From, State) ->
    {stop, shutdown, ok, State};

handle_call(Unexpected, _From, State) ->
    ?LOG_WARN("Unexpected call received: ~p", [Unexpected]),
    {noreply, State}.

handle_cast(Unexpected, State) ->
    ?LOG_WARN("Unexpected cast received: ~p", [Unexpected]),
    {noreply, State}.

handle_info({'EXIT', Pid, Reason}, State) ->
    ?LOG_DEBUG("Process ~p died with reason ~p and sent exit signal", [Pid, Reason]),
    FinalState = try_unsubscribe(Pid, State),
    {noreply, FinalState};

handle_info(Unexpected, State) ->
    ?LOG_WARN("Unexpected message received: ~p", [Unexpected]),
    {noreply, State}.

terminate(Reason, _) ->
    ?LOG_INFO("Pubsub channel terminated with reason: ~p", [Reason]),
    ok.

code_change(_, State, _) ->
    {ok, State}.

%

create_state() ->
    ordsets:new().

do_subscribe(C, Clients) ->
    case ordsets:add_element(C, Clients) of
        Clients ->
            {error, subscribed_already};
        NewClients ->
            {ok, NewClients}
    end.

do_unsubscribe(C, Clients) ->
    case ordsets:del_element(C, Clients) of
        Clients ->
            {error, not_subscribed};
        NewClients ->
            {ok, NewClients}
    end.

try_unsubscribe(C, Clients) ->
    ordsets:del_element(C, Clients).

do_publish(Pid, Payload, Clients) ->
    List = ordsets:to_list(Clients),
    do_publish(Pid, Payload, ok, List).

do_publish(_, _, Result, []) ->
    Result;

do_publish(Pid, Payload, Result, [Pid | Rest]) ->
    do_publish(Pid, Payload, Result, Rest);

do_publish(Pid, Payload, Result, [Client | Rest]) ->
    Client ! {publication, Payload},
    do_publish(Pid, Payload, Result, Rest).

% Tests

-ifdef(TEST).

-include_lib("eunit/include/eunit.hrl").

do_test_() ->
    {setup, fun test_prepare/0, fun test_cleanup/1, fun (Pid) -> [
        test_double_subscription(Pid),
        test_interoperability(Pid)
    ] end}.

test_prepare() ->
    {ok, Pid} = gen_server:start(?MODULE, [], []),
    Pid.

test_cleanup(Pid) ->
    epubsub_channel:stop(Pid).

test_double_subscription(Pid) ->
    ?_test(double_subscription(Pid)).

test_interoperability(Pid) ->
    ?_test(interoperability(Pid)).

double_subscription(Pid) ->
    ok = epubsub_channel:subscribe(Pid),
    {error, subscribed_already} = epubsub_channel:subscribe(Pid),
    ok = epubsub_channel:unsubscribe(Pid),
    {error, not_subscribed} = epubsub_channel:unsubscribe(Pid),
    ok.

interoperability(Pid) ->
    Pids = [spawn_monitor(fun () -> subprocess(N, Pid) end) || N <- [1, 2, 3] ],
    ok = epubsub_channel:subscribe(Pid),
    ok = epubsub_channel:publish(Pid, 0),
    Messages = wait(Pids, []),
    ?assertEqual(0, length([ok || {publication, 0} <- Messages])),
    ?assertEqual(3, length([ok || {publication, 1} <- Messages])),
    ?assertEqual(5, length([ok || {publication, 2} <- Messages])),
    ?assertEqual(4, length([ok || {publication, 3} <- Messages])).

subprocess(N, Pid) ->
    ok = epubsub_channel:subscribe(Pid),
    loop(N, Pid).

loop(N, Pid) ->
    receive
        {publication, N} ->
            ?debugFmt("~p: Done", [N]),
            epubsub_channel:publish(Pid, N + 1);
        {publication, M} ->
            ?debugFmt("~p: Got ~p", [N, M]),
            epubsub_channel:publish(Pid, M + 1),
            loop(N, Pid)
    end.

wait([], Acc) ->
    receive
        Message ->
            wait([], [Message | Acc])
    after 0 ->
        Acc
    end;

wait([{Pid, Ref} | Rest], Acc) ->
    receive
        {'DOWN', Ref, process, Pid, Reason} ->
            ?debugFmt("Process ~p done with reason ~p", [Pid, Reason])
    end,
    wait(Rest, Acc).

-endif.
