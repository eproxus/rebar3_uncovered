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
        src/foo.erl:2 0 line2
        src/foo.erl:3 0 line3
        """,
        unicode:characters_to_binary(format(Regions, raw, false))
    ).

raw_format_context_lines_test() ->
    Regions = [
        #{
            file => ~"src/foo.erl",
            lines => [
                {1, ~"covered", covered, 5},
                {2, ~"uncovered", uncovered, 0},
                {3, ~"context", covered, none}
            ]
        }
    ],
    ?assertEqual(
        ~b"""
        src/foo.erl:1 5 covered
        src/foo.erl:2 0 uncovered
        src/foo.erl:3 - context
        """,
        unicode:characters_to_binary(format(Regions, raw, false))
    ).

raw_format_multiple_regions_test() ->
    R1 = #{
        file => ~"src/foo.erl",
        lines => [{1, ~"x", uncovered, 0}]
    },
    R2 = #{
        file => ~"src/foo.erl",
        lines => [{5, ~"y", uncovered, 0}]
    },
    ?assertEqual(
        ~b"""
        src/foo.erl:1 0 x
        src/foo.erl:5 0 y
        """,
        unicode:characters_to_binary(format([R1, R2], raw, false))
    ).

raw_format_empty_regions_test() ->
    ?assertEqual(~"", unicode:characters_to_binary(format([], raw, false))).

%--- Tests: human format -------------------------------------------------------

human_format_test() ->
    % LW=1, CW_raw=2: border = 3+1+4+1+21=30
    Expected = unicode:characters_to_binary([
        "═══╤════╤═════════════════════\n",
        "   │    │ src/foo.erl\n",
        "═══╪════╪═════════════════════\n",
        " 1 │ 42 │ line1\n",
        " 2 │ 0  │ line2\n",
        "───┴────┴─────────────────────"
    ]),
    ?assertEqual(
        Expected,
        unicode:characters_to_binary(format([region()], human, false, true, 30))
    ).

human_format_empty_regions_test() ->
    ?assertEqual(~"", unicode:characters_to_binary(format([], human, false))).

human_format_multiple_files_test() ->
    % LW=1, CW_raw=1: border = 3+1+3+1+8=16
    R1 = #{file => ~"a.erl", lines => [{1, ~"x", uncovered, 0}]},
    R2 = #{file => ~"b.erl", lines => [{1, ~"y", uncovered, 0}]},
    Expected = unicode:characters_to_binary([
        "═══╤═══╤════════\n",
        "   │   │ a.erl\n",
        "═══╪═══╪════════\n",
        " 1 │ 0 │ x\n",
        "───┴───┴────────",
        "\n",
        "═══╤═══╤════════\n",
        "   │   │ b.erl\n",
        "═══╪═══╪════════\n",
        " 1 │ 0 │ y\n",
        "───┴───┴────────"
    ]),
    ?assertEqual(
        Expected,
        unicode:characters_to_binary(format([R1, R2], human, false, true, 16))
    ).

human_format_same_file_grouped_test() ->
    % LW=1, CW_raw=1: border = 3+1+3+1+8=16
    R1 = #{file => ~"a.erl", lines => [{1, ~"x", uncovered, 0}]},
    R2 = #{file => ~"a.erl", lines => [{5, ~"y", uncovered, 0}]},
    Expected = unicode:characters_to_binary([
        "═══╤═══╤════════\n",
        "   │   │ a.erl\n",
        "═══╪═══╪════════\n",
        " 1 │ 0 │ x\n",
        " ⋮ ┊   ┊\n",
        " 5 │ 0 │ y\n",
        "───┴───┴────────"
    ]),
    ?assertEqual(
        Expected,
        unicode:characters_to_binary(format([R1, R2], human, false, true, 16))
    ).

human_format_non_executable_line_test() ->
    % LW=1, CW_raw=1: border = 3+1+3+1+12=20
    Regions = [
        #{
            file => ~"f.erl",
            lines => [
                {1, ~"x", uncovered, 0},
                {2, ~"% comment", covered, none}
            ]
        }
    ],
    Expected = unicode:characters_to_binary([
        "═══╤═══╤════════════\n",
        "   │   │ f.erl\n",
        "═══╪═══╪════════════\n",
        " 1 │ 0 │ x\n",
        " 2 │   │ % comment\n",
        "───┴───┴────────────"
    ]),
    ?assertEqual(
        Expected,
        unicode:characters_to_binary(format(Regions, human, false, true, 20))
    ).

%--- Tests: dynamic widths -----------------------------------------------------

human_format_dynamic_widths_test() ->
    % LW=3, CW_raw=4: border = 5+1+6+1+17=30
    Regions = [
        #{
            file => ~"f.erl",
            lines => [
                {1, ~"first", uncovered, 0},
                {100, ~"hundredth", uncovered, 1234}
            ]
        }
    ],
    Expected = unicode:characters_to_binary([
        "═════╤══════╤═════════════════\n",
        "     │      │ f.erl\n",
        "═════╪══════╪═════════════════\n",
        "   1 │ 0    │ first\n",
        " 100 │ 1234 │ hundredth\n",
        "─────┴──────┴─────────────────"
    ]),
    ?assertEqual(
        Expected,
        unicode:characters_to_binary(format(Regions, human, false, true, 30))
    ).

%--- Tests: counts flag --------------------------------------------------------

human_format_no_counts_test() ->
    % LW=1, no counts: border = 3+1+16=20
    Expected = unicode:characters_to_binary([
        "═══╤════════════════\n",
        "   │ src/foo.erl\n",
        "═══╪════════════════\n",
        " 1 │ line1\n",
        " 2 │ line2\n",
        "───┴────────────────"
    ]),
    ?assertEqual(
        Expected,
        unicode:characters_to_binary(
            format([region()], human, false, false, 20)
        )
    ).

human_format_wrap_test() ->
    C = 20,
    Regions = [
        #{
            file => ~"f.erl",
            lines => [{1, ~"longline that wraps!", covered, 5}]
        }
    ],
    Expected = unicode:characters_to_binary([
        "═══╤═══╤════════════\n",
        "   │   │ f.erl\n",
        "═══╪═══╪════════════\n",
        " 1 │ 5 │ longline th\n",
        "   │   │ at wraps!\n",
        "───┴───┴────────────"
    ]),
    ?assertEqual(
        Expected,
        unicode:characters_to_binary(format(Regions, human, false, true, C))
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
        src/foo.erl:2 line2
        src/foo.erl:3 line3
        """,
        unicode:characters_to_binary(format(Regions, raw, false, false))
    ).

%--- Tests: color --------------------------------------------------------------

human_color_line_test() ->
    Regions = [#{file => ~"f.erl", lines => [{1, ~"x", uncovered, 0}]}],
    <<_/binary>> =
        Result = unicode:characters_to_binary(
            format(Regions, human, true, true, 20)
        ),
    % Verify uncovered source bg wraps entire line
    ?assert(binary:match(Result, ~b"\e[48;2;60;20;20m") =/= nomatch),
    % Verify bold uncovered line number
    ?assert(binary:match(Result, ~b"\e[1m") =/= nomatch),
    % Verify uncovered count fg color
    ?assert(binary:match(Result, ~b"\e[38;2;255;120;100m") =/= nomatch).

human_color_covered_line_test() ->
    Regions = [#{file => ~"f.erl", lines => [{1, ~"x", covered, 5}]}],
    <<_/binary>> =
        Result = unicode:characters_to_binary(
            format(Regions, human, true, true, 20)
        ),
    % Verify covered count fg color
    ?assert(binary:match(Result, ~b"\e[38;2;100;230;100m") =/= nomatch),
    % Verify no bg on covered lines
    ?assert(binary:match(Result, ~b"\e[48;2;60;20;20m") =:= nomatch).

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
    format(Regions, Format, Color, Counts, 80).

format(Regions, Format, Color, Counts, Columns) ->
    rebar3_uncovered_format:format_lines(
        Regions, #{
            format => Format,
            color => Color,
            context => 2,
            counts => Counts,
            columns => Columns
        }
    ).
