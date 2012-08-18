%
% EPubSub WebSocket handler.
%

-module(epubsub_websocket).
-behaviour(cowboy_http_websocket_handler).

-include("epubsub_logger.hrl").

-export([
    init/3,
    terminate/2
]).

-export([
    websocket_init/3,
    websocket_handle/3,
    websocket_info/3,
    websocket_terminate/3
]).

% Behaviour

init({_Any, http}, Request, Options) ->
    case cowboy_http_req:header('Upgrade', Request) of
        {undefined, _}       -> {shutdown, Request, undefined};
        {<<"websocket">>, _} -> {upgrade, protocol, cowboy_http_websocket};
        {<<"WebSocket">>, _} -> {upgrade, protocol, cowboy_http_websocket}
    end.

terminate(_Request, _State) ->
    {error, websocket}.

websocket_init(_Any, Request, State) ->
    ?LOG_DEBUG("WebSocket client accepted on ~p", [element(1, cowboy_http_req:peer(Request))]),
    ok = epubsub_channel:subscribe(State),
    {ok, Request, State, hibernate}.

websocket_handle({ping, _}, Request, State) ->
    ?LOG_DEBUG("WebSocket process was poked"),
    {ok, Request, State, hibernate};

websocket_handle({text, Message}, Request, State) ->
    ?LOG_DEBUG("WebSocket instance received a message: ~p", [Message]),
    ok = epubsub_channel:publish(State, Message),
    {ok, Request, State, hibernate};

websocket_handle(Unexpected, Request, State) ->
    ?LOG_WARN("WebSocket instance got an unexpected message from client: ~p", [Unexpected]),
    {ok, Request, State, hibernate}.

websocket_info({publication, Payload}, Request, State) ->
    {reply, {text, respond(Payload)}, Request, State, hibernate};

websocket_info(Unexpected, Request, State) ->
    ?LOG_WARN("WebSocket instance received unexpected message: ~p", [Unexpected]),
    {ok, Request, State, hibernate}.

websocket_terminate(Reason, _Request, _State) ->
    ?LOG_DEBUG("WebSocket client released because of ~p", [Reason]),
    ok.

%%

respond(Payload) ->
    Payload.
