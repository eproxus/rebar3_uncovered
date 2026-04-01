-module(rebar3_uncovered_format_tests).

-include_lib("eunit/include/eunit.hrl").

%--- Tests: raw format ---------------------------------------------------------

raw_format_test() ->
    Regions = [
        #{
            file => ~"src/foo.erl",
            lines => [{2, ~"line2", uncovered}, {3, ~"line3", uncovered}]
        }
    ],
    ?assertEqual(
        ~b"""
        src/foo.erl:2\tline2
        src/foo.erl:3\tline3

        """,
        iolist_to_binary(format(Regions, raw, false))
    ).

raw_format_empty_regions_test() ->
    ?assertEqual(~"", iolist_to_binary(format([], raw, false))).

%--- Tests: human format -------------------------------------------------------

human_format_test() ->
    ?assertEqual(
        ~"""
        src/foo.erl
           1   line1
           2 > line2

        """,
        iolist_to_binary(format([region()], human, false))
    ).

human_format_empty_regions_test() ->
    ?assertEqual(~"", iolist_to_binary(format([], human, false))).

human_format_multiple_regions_test() ->
    R1 = #{file => ~"a.erl", lines => [{1, ~"x", uncovered}]},
    R2 = #{file => ~"b.erl", lines => [{1, ~"y", uncovered}]},
    ?assertEqual(
        ~"""
        a.erl
           1 > x

        b.erl
           1 > y

        """,
        iolist_to_binary(format([R1, R2], human, false))
    ).

%--- Tests: color --------------------------------------------------------------

human_color_uncovered_test() ->
    Regions = [#{file => ~"f.erl", lines => [{1, ~"x", uncovered}]}],
    ?assertEqual(
        ~b"""
        f.erl
        \e[31m   1 > x
        \e[0m
        """,
        iolist_to_binary(format(Regions, human, true))
    ).

human_color_covered_test() ->
    Regions = [#{file => ~"f.erl", lines => [{1, ~"x", covered}]}],
    ?assertEqual(
        ~"""
        f.erl
           1   x

        """,
        iolist_to_binary(format(Regions, human, true))
    ).

%--- Helpers -------------------------------------------------------------------

region() ->
    #{
        file => ~"src/foo.erl",
        lines => [
            {1, ~"line1", covered},
            {2, ~"line2", uncovered}
        ]
    }.

format(Regions, Format, Color) ->
    rebar3_uncovered_format:format_lines(
        Regions, #{format => Format, color => Color, context => 2}
    ).
