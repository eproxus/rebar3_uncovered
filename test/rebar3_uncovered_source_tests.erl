-module(rebar3_uncovered_source_tests).

-include_lib("eunit/include/eunit.hrl").

%--- Tests ---------------------------------------------------------------------

build_regions_zero_context_test() ->
    Regions = build_regions([5], 0),
    ?assertMatch([#{lines := [{5, _, uncovered, _}]}], Regions).

build_regions_context_adds_surrounding_lines_test() ->
    Regions = build_regions([9], 2),
    [#{lines := Lines}] = Regions,
    ?assertEqual(
        [
            {7, covered},
            {8, covered},
            {9, uncovered},
            {10, covered},
            {11, covered}
        ],
        [{N, S} || {N, _, S, _} <- Lines]
    ).

build_regions_context_clamps_to_file_bounds_test() ->
    Regions = build_regions([1], 3),
    [#{lines := Lines}] = Regions,
    ?assertEqual(1, element(1, hd(Lines))).

build_regions_merges_nearby_uncovered_lines_test() ->
    % Lines 9 and 10 with context 2: ranges 7-11 and 8-12 overlap -> one region
    Regions = build_regions([9, 10], 2),
    ?assertMatch([#{lines := [_ | _]}], Regions).

build_regions_separates_distant_uncovered_lines_test() ->
    % Lines 5 and 15 with context 1: ranges 4-6 and 14-16 don't overlap
    Regions = build_regions([5, 15], 1),
    ?assertMatch([_, _], Regions).

build_regions_enriches_lines_with_source_test() ->
    #{files := Files} = build_regions_state([5], 0),
    File = source_file(),
    ?assertMatch(#{5 := #{source := _, count := 0}}, maps:get(File, Files)).

build_regions_adds_non_analyzed_lines_test() ->
    #{files := Files} = build_regions_state([5], 1),
    File = source_file(),
    FileLines = maps:get(File, Files),
    % Line 4 is not in cover analysis but should have source from enrichment
    ?assertMatch(#{source := _}, maps:get(4, FileLines)).

%--- Helpers -------------------------------------------------------------------

source_file() ->
    "test/data/source_app/src/mymod.erl".

build_regions(LineNos, Context) ->
    #{regions := Regions} = build_regions_state(LineNos, Context),
    Regions.

build_regions_state(LineNos, Context) ->
    File = source_file(),
    FileLines = #{N => #{count => 0, show => true} || N <- LineNos},
    rebar3_uncovered_source:build_regions(#{
        files => #{File => FileLines},
        path_filters => [],
        opts => #{context => Context, git => false}
    }).
