-module(mymod).

-export([hello/0, foo/0, bar/0]).

hello() -> world.

foo() ->
    case rand:uniform(2) of
        1 -> a;
        2 -> b
    end.

bar() ->
    case rand:uniform(2) of
        1 -> x;
        2 -> y
    end.
