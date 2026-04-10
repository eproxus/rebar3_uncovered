-module(rebar3_uncovered_cover_tests).

-include_lib("eunit/include/eunit.hrl").

-hank([{unnecessary_function_arguments, [cleanup]}]).

%--- Tests ---------------------------------------------------------------------

uncovered_lines_test_() ->
    {setup, fun setup/0, fun cleanup/1, fun(App) ->
        [
            {"eunit returns uncovered lines", fun() ->
                #{lines := Result} = rebar3_uncovered_cover:uncovered_lines(
                    #{opts => #{coverage => eunit}, apps => [App]}
                ),
                ?assert(length(Result) > 0)
            end},
            {"all entries have module and line keys", fun() ->
                #{lines := Result} = rebar3_uncovered_cover:uncovered_lines(
                    #{opts => #{coverage => eunit}, apps => [App]}
                ),
                lists:foreach(
                    fun(Entry) ->
                        ?assertMatch(#{module := _, line := _}, Entry),
                        #{module := Mod, line := Line} = Entry,
                        ?assert(is_atom(Mod)),
                        ?assert(is_integer(Line) andalso Line > 0)
                    end,
                    Result
                )
            end},
            {"contains known uncovered line", fun() ->
                #{lines := Result} = rebar3_uncovered_cover:uncovered_lines(
                    #{opts => #{coverage => eunit}, apps => [App]}
                ),
                ?assert(
                    lists:any(
                        fun(#{module := Mod, line := Line}) ->
                            Mod =:= gaffer_driver andalso Line =:= 138
                        end,
                        Result
                    )
                )
            end},
            {"aggregate matches wildcard pattern", fun() ->
                #{lines := Result} = rebar3_uncovered_cover:uncovered_lines(
                    #{opts => #{coverage => aggregate}, apps => [App]}
                ),
                ?assert(length(Result) > 0)
            end},
            {"includes multiple modules with uncovered lines", fun() ->
                #{lines := Result} = rebar3_uncovered_cover:uncovered_lines(
                    #{opts => #{coverage => eunit}, apps => [App]}
                ),
                Modules = lists:usort([
                    Mod
                 || #{module := Mod} <:- Result
                ]),
                ?assert(length(Modules) > 1)
            end},
            {"counts map has entries for all analyzed modules", fun() ->
                #{counts := Counts} = rebar3_uncovered_cover:uncovered_lines(
                    #{opts => #{coverage => eunit}, apps => [App]}
                ),
                ?assert(map_size(Counts) > 0),
                maps:foreach(
                    fun(Mod, ModCounts) ->
                        ?assert(is_atom(Mod)),
                        ?assert(is_map(ModCounts)),
                        maps:foreach(
                            fun(Line, Cov) ->
                                ?assert(is_integer(Line) andalso Line > 0),
                                ?assert(is_integer(Cov) andalso Cov >= 0)
                            end,
                            ModCounts
                        )
                    end,
                    Counts
                )
            end}
        ]
    end}.

no_coverdata_test_() ->
    {setup, fun setup_empty/0, fun cleanup/1, fun(App) ->
        [
            {"no coverdata returns empty lines and counts", fun() ->
                #{lines := Lines, counts := Counts} =
                    rebar3_uncovered_cover:uncovered_lines(
                        #{opts => #{coverage => eunit}, apps => [App]}
                    ),
                ?assertEqual([], Lines),
                ?assertEqual(#{}, Counts)
            end},
            {"ct pattern does not match eunit file", fun() ->
                App1 = make_app(fixture_dir(~"cover_app")),
                #{lines := Lines, counts := Counts} =
                    rebar3_uncovered_cover:uncovered_lines(
                        #{opts => #{coverage => ct}, apps => [App1]}
                    ),
                ?assertEqual([], Lines),
                ?assertEqual(#{}, Counts)
            end}
        ]
    end}.

%--- Setup / Cleanup -----------------------------------------------------------

setup() -> make_app(fixture_dir(~"cover_app")).

setup_empty() -> make_app(fixture_dir(~"empty_app")).

cleanup(_) ->
    Modules = cover:imported_modules(),
    true = is_list(Modules),
    [cover:reset(M) || M <:- Modules],
    ok.

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
