-module(foo).

-export([covered/0, uncovered/0]).

covered() ->
    ok.

uncovered() ->
    not_called.
