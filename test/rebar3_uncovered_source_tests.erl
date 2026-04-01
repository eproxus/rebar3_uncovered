-module(rebar3_uncovered_source_tests).

-include_lib("eunit/include/eunit.hrl").

%--- Tests ---------------------------------------------------------------------

resolve_files_returns_relative_paths_test() ->
    App = make_app(fixture_dir(~"source_app")),
    Input = [#{module => mymod, line => 5}],
    [#{file := File}] = rebar3_uncovered_source:resolve_files(Input, [App]),
    ?assertEqual("test/data/source_app/src/mymod.erl", File).

resolve_files_filters_unknown_modules_test() ->
    App = make_app(fixture_dir(~"source_app")),
    Input = [#{module => nonexistent, line => 1}],
    ?assertEqual([], rebar3_uncovered_source:resolve_files(Input, [App])).

read_regions_zero_context_test() ->
    Regions = read_regions([5], 0),
    ?assertMatch([#{lines := [{5, _, uncovered}]}], Regions).

read_regions_context_adds_surrounding_lines_test() ->
    Regions = read_regions([9], 2),
    [#{lines := Lines}] = Regions,
    ?assertEqual(
        [
            {7, covered},
            {8, covered},
            {9, uncovered},
            {10, covered},
            {11, covered}
        ],
        [{N, S} || {N, _, S} <- Lines]
    ).

read_regions_context_clamps_to_file_bounds_test() ->
    Regions = read_regions([1], 3),
    [#{lines := Lines}] = Regions,
    ?assertEqual(1, element(1, hd(Lines))).

read_regions_merges_nearby_uncovered_lines_test() ->
    % Lines 9 and 10 with context 2: ranges 7-11 and 8-12 overlap -> one region
    Regions = read_regions([9, 10], 2),
    ?assertMatch([#{lines := [_ | _]}], Regions).

read_regions_separates_distant_uncovered_lines_test() ->
    % Lines 5 and 15 with context 1: ranges 4-6 and 14-16 don't overlap
    Regions = read_regions([5, 15], 1),
    ?assertMatch([_, _], Regions).

%--- Helpers -------------------------------------------------------------------

fixture_dir(Name) ->
    filename:join([project_root(), "test", "data", Name]).

project_root() ->
    BeamPath = code:which(?MODULE),
    true = is_list(BeamPath),
    find_project_root(filename:dirname(BeamPath)).

find_project_root("/") ->
    error(project_root_not_found);
find_project_root(Dir) ->
    case filelib:is_file(filename:join(Dir, "rebar.config")) of
        true -> Dir;
        false -> find_project_root(filename:dirname(Dir))
    end.

read_regions(LineNos, Context) ->
    App = make_app(fixture_dir(~"source_app")),
    Input = [#{module => mymod, line => N} || N <- LineNos],
    Resolved = rebar3_uncovered_source:resolve_files(Input, [App]),
    rebar3_uncovered_source:read_regions(Resolved, Context).

make_app(Dir) ->
    {ok, App0} = rebar_app_info:new(test_app, "0.0.0"),
    rebar_app_info:dir(App0, Dir).
