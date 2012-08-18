%
% PubSub HTTP service holder process.
%

-module(epubsub_http).
-behaviour(gen_server).

-include("epubsub_logger.hrl").

%% API
-export([
    start_link/1,
    start_link/2
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

%%

start_link(Options) ->
    gen_server:start_link(?MODULE, Options, []).

start_link(Name, Options) ->
    gen_server:start_link(Name, ?MODULE, Options, []).

%%

init(Options) ->

    ?LOG_INFO("Starting HTTP service..."),

    [Host, Port, PoolSize] = deepprops:values([
        {host, "0.0.0.0"},
        {port, 8000},
        {pool_size, 32}
    ], Options),

    {ok, HostTuple} = inet:getaddr(Host, inet),
    Transport = cowboy_tcp_transport,
    Proto = cowboy_http_protocol,
    TransportOptions = [{ip, HostTuple}, {port, Port}],

    Dispatch = [
        {'_', [
            {[<<"channel">>], 
                epubsub_websocket, 
                epubsub_channel
            },
            {['...'], 
                cowboy_http_static, [
                    {directory, {priv_dir, epubsub, [<<"www">>]}},
                    {mimetypes, {fun mimetypes:path_to_mimes/2, default}}
                ]
            }
        ]}
    ],

    {ok, Pid} = cowboy:start_listener(?MODULE, PoolSize, Transport, TransportOptions, Proto, [{dispatch, Dispatch}]),
    {ok, Pid, hibernate}.

handle_call(Unexpected, _From, State) ->
    ?LOG_WARN("Unexpected call received: ~p", [Unexpected]),
    {noreply, State, hibernate}.

handle_cast(Unexpected, State) ->
    ?LOG_WARN("Unexpected cast received: ~p", [Unexpected]),
    {noreply, State, hibernate}.

handle_info(Unexpected, State) ->
    ?LOG_WARN("Unexpected message received: ~p", [Unexpected]),
    {noreply, State, hibernate}.

terminate(_, _) ->
    ?LOG_INFO("Terminating HTTP service..."),
    ok = cowboy:stop_listener(?MODULE).

code_change(_, State, _) ->
    {ok, State}.