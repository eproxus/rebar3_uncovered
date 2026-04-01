-module(rebar3_uncovered_format_tests).

-include_lib("eunit/include/eunit.hrl").

%--- Tests: raw format ---------------------------------------------------------

raw_format_outputs_uncovered_lines_test() ->
    Regions = [
        #{
            file => ~"src/foo.erl",
            lines => [{2, ~"line2", uncovered}, {3, ~"line3", uncovered}]
        }
    ],
    Out = iolist_to_binary(format(Regions, raw, false)),
    ?assertEqual(~"src/foo.erl:2\tline2\nsrc/foo.erl:3\tline3\n", Out).

raw_format_empty_regions_test() ->
    ?assertEqual(~"", iolist_to_binary(format([], raw, false))).

%--- Tests: human format -------------------------------------------------------

human_format_shows_file_and_markers_test() ->
    Regions = [region()],
    Out = iolist_to_binary(format(Regions, human, false)),
    assert_contains(Out, ~"src/foo.erl"),
    assert_contains(Out, ~">"),
    assert_contains(Out, ~"  ").

human_format_uncovered_marker_test() ->
    Regions = [#{file => ~"f.erl", lines => [{1, ~"x", uncovered}]}],
    Out = iolist_to_binary(format(Regions, human, false)),
    assert_contains(Out, ~"> x").

human_format_covered_marker_test() ->
    Regions = [#{file => ~"f.erl", lines => [{1, ~"x", covered}]}],
    Out = iolist_to_binary(format(Regions, human, false)),
    assert_contains(Out, ~"  x"),
    assert_not_contains(Out, ~">").

human_format_empty_regions_test() ->
    ?assertEqual(~"", iolist_to_binary(format([], human, false))).

human_format_multiple_regions_joined_test() ->
    R1 = #{file => ~"a.erl", lines => [{1, ~"x", uncovered}]},
    R2 = #{file => ~"b.erl", lines => [{1, ~"y", uncovered}]},
    Out = iolist_to_binary(format([R1, R2], human, false)),
    assert_contains(Out, ~"a.erl"),
    assert_contains(Out, ~"b.erl"),
    % Regions are separated by a blank line
    assert_contains(Out, ~"\n\n").

%--- Tests: color --------------------------------------------------------------

human_color_wraps_uncovered_in_red_test() ->
    Regions = [#{file => ~"f.erl", lines => [{1, ~"x", uncovered}]}],
    Out = iolist_to_binary(format(Regions, human, true)),
    assert_contains(Out, ~"\e[31m"),
    assert_contains(Out, ~"\e[0m").

human_no_color_has_no_ansi_test() ->
    Regions = [#{file => ~"f.erl", lines => [{1, ~"x", uncovered}]}],
    Out = iolist_to_binary(format(Regions, human, false)),
    assert_not_contains(Out, ~"\e[").

human_color_does_not_wrap_covered_test() ->
    Regions = [#{file => ~"f.erl", lines => [{1, ~"x", covered}]}],
    Out = iolist_to_binary(format(Regions, human, true)),
    assert_not_contains(Out, ~"\e[31m").

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

assert_contains(Haystack, Needle) ->
    ?assertNotEqual(
        nomatch,
        binary:match(Haystack, Needle),
        #{expected_to_contain => Needle, in => Haystack}
    ).

assert_not_contains(Haystack, Needle) ->
    ?assertEqual(
        nomatch,
        binary:match(Haystack, Needle),
        #{expected_not_to_contain => Needle, in => Haystack}
    ).
