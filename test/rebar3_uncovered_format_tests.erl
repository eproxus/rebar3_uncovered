-module(rebar3_uncovered_format_tests).

-include_lib("eunit/include/eunit.hrl").

%--- Tests: raw format ---------------------------------------------------------

raw_format_test() ->
    Regions = [
        #{
            file => ~"src/foo.erl",
            lines => [{2, ~"line2", uncovered, 0}, {3, ~"line3", uncovered, 0}]
        }
    ],
    ?assertEqual(
        ~b"""
        src/foo.erl:2\t0\tline2
        src/foo.erl:3\t0\tline3

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
           1    42   line1
           2     0 > line2

        """,
        iolist_to_binary(format([region()], human, false))
    ).

human_format_empty_regions_test() ->
    ?assertEqual(~"", iolist_to_binary(format([], human, false))).

human_format_multiple_regions_test() ->
    R1 = #{file => ~"a.erl", lines => [{1, ~"x", uncovered, 0}]},
    R2 = #{file => ~"b.erl", lines => [{1, ~"y", uncovered, 0}]},
    ?assertEqual(
        ~"""
        a.erl
           1     0 > x

        b.erl
           1     0 > y

        """,
        iolist_to_binary(format([R1, R2], human, false))
    ).

human_format_non_executable_line_test() ->
    Regions = [
        #{
            file => ~"f.erl",
            lines => [
                {1, ~"x", uncovered, 0},
                {2, ~"% comment", covered, none}
            ]
        }
    ],
    ?assertEqual(
        ~"""
        f.erl
           1     0 > x
           2         % comment

        """,
        iolist_to_binary(format(Regions, human, false))
    ).

%--- Tests: counts flag --------------------------------------------------------

human_format_no_counts_test() ->
    ?assertEqual(
        ~"""
        src/foo.erl
           1   line1
           2 > line2

        """,
        iolist_to_binary(format([region()], human, false, false))
    ).

raw_format_no_counts_test() ->
    Regions = [
        #{
            file => ~"src/foo.erl",
            lines => [{2, ~"line2", uncovered, 0}, {3, ~"line3", uncovered, 0}]
        }
    ],
    ?assertEqual(
        ~b"""
        src/foo.erl:2\tline2
        src/foo.erl:3\tline3

        """,
        iolist_to_binary(format(Regions, raw, false, false))
    ).

%--- Tests: color --------------------------------------------------------------

human_color_uncovered_test() ->
    Regions = [#{file => ~"f.erl", lines => [{1, ~"x", uncovered, 0}]}],
    ?assertEqual(
        ~b"""
        f.erl
        \e[31m   1     0 > x
        \e[0m
        """,
        iolist_to_binary(format(Regions, human, true))
    ).

human_color_covered_test() ->
    Regions = [#{file => ~"f.erl", lines => [{1, ~"x", covered, 5}]}],
    ?assertEqual(
        ~"""
        f.erl
           1     5   x

        """,
        iolist_to_binary(format(Regions, human, true))
    ).

%--- Helpers -------------------------------------------------------------------

region() ->
    #{
        file => ~"src/foo.erl",
        lines => [
            {1, ~"line1", covered, 42},
            {2, ~"line2", uncovered, 0}
        ]
    }.

format(Regions, Format, Color) -> format(Regions, Format, Color, true).

format(Regions, Format, Color, Counts) ->
    rebar3_uncovered_format:format_lines(
        Regions, #{
            format => Format, color => Color, context => 2, counts => Counts
        }
    ).
