%
% Root application supervisor.
%

-module(epubsub_sup).
-behaviour(supervisor).

%

-export([start_link/0, init/1]).

%

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%

init([]) ->
    {ok, {
        {one_for_one, 5, 10}, 
        [
            supstance:permanent(epubsub_channel, local, []),
            supstance:permanent(epubsub_http, local, inherit)
        ]
    }}.
