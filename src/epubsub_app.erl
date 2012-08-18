%
% Application behaviuor implementation.
%

-module(epubsub_app).
-behaviour(application).

%

-export([start/2, stop/1]).

%

start(_StartType, _StartArgs) ->
    epubsub_sup:start_link().

stop(_State) ->
    ok.
