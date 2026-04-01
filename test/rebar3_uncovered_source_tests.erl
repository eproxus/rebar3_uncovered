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

read_regions_test() ->
    App = make_app(fixture_dir(~"source_app")),
    Input = [#{module => mymod, line => 5}],
    [#{file := File}] = rebar3_uncovered_source:resolve_files(Input, [App]),
    Regions = rebar3_uncovered_source:read_regions(
        [#{file => File, line => 5}], 0
    ),
    ?assertMatch(
        [#{file := "test/data/source_app/src/mymod.erl", lines := [{5, _, _}]}],
        Regions
    ).

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

make_app(Dir) ->
    {ok, App0} = rebar_app_info:new(test_app, "0.0.0"),
    rebar_app_info:dir(App0, Dir).
