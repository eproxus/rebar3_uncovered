-module(rebar3_uncovered_cover_tests).

-include_lib("eunit/include/eunit.hrl").

-hank([{unnecessary_function_arguments, [cleanup]}]).

%--- Tests ---------------------------------------------------------------------

analyse_lines_test_() ->
    {setup, fun setup/0, fun cleanup/1, fun(App) ->
        [
            {"returns lines grouped by file", fun() ->
                #{files := Result} = rebar3_uncovered_cover:analyse_lines(
                    #{opts => #{coverage => eunit}, apps => [App]}
                ),
                ?assert(map_size(Result) > 0),
                maps:foreach(
                    fun(File, FileLines) ->
                        ?assert(is_list(File)),
                        ?assert(map_size(FileLines) > 0),
                        maps:foreach(
                            fun(Line, Info) ->
                                ?assert(is_integer(Line) andalso Line > 0),
                                ?assertMatch(#{count := _}, Info),
                                #{count := C} = Info,
                                ?assert(is_integer(C) andalso C >= 0)
                            end,
                            FileLines
                        )
                    end,
                    Result
                )
            end},
            {"uncovered lines have show flag", fun() ->
                #{files := Result} = rebar3_uncovered_cover:analyse_lines(
                    #{opts => #{coverage => eunit}, apps => [App]}
                ),
                HasShow = lists:any(
                    fun({_, FileLines}) ->
                        lists:any(
                            fun
                                ({_, #{show := true}}) -> true;
                                (_) -> false
                            end,
                            maps:to_list(FileLines)
                        )
                    end,
                    maps:to_list(Result)
                ),
                ?assert(HasShow)
            end},
            {"covered lines do not have show flag", fun() ->
                #{files := Result} = rebar3_uncovered_cover:analyse_lines(
                    #{opts => #{coverage => eunit}, apps => [App]}
                ),
                HasCoveredWithoutShow = lists:any(
                    fun({_, FileLines}) ->
                        lists:any(
                            fun
                                ({_, #{count := C} = Info}) when C > 0 ->
                                    not maps:is_key(show, Info);
                                (_) ->
                                    false
                            end,
                            maps:to_list(FileLines)
                        )
                    end,
                    maps:to_list(Result)
                ),
                ?assert(HasCoveredWithoutShow)
            end},
            {"contains known uncovered line", fun() ->
                #{files := Result} = rebar3_uncovered_cover:analyse_lines(
                    #{opts => #{coverage => eunit}, apps => [App]}
                ),
                FooFile = [
                    F
                 || F <- maps:keys(Result), lists:suffix("foo.erl", F)
                ],
                ?assertMatch([_], FooFile),
                [File] = FooFile,
                ?assertMatch(
                    #{9 := #{count := 0, show := true}}, maps:get(File, Result)
                )
            end},
            {"includes multiple files", fun() ->
                #{files := Result} = rebar3_uncovered_cover:analyse_lines(
                    #{opts => #{coverage => eunit}, apps => [App]}
                ),
                ?assert(map_size(Result) > 1)
            end},
            {"aggregate matches wildcard pattern", fun() ->
                #{files := Result} = rebar3_uncovered_cover:analyse_lines(
                    #{opts => #{coverage => aggregate}, apps => [App]}
                ),
                ?assert(map_size(Result) > 0)
            end}
        ]
    end}.

no_coverdata_test_() ->
    {setup, fun setup_empty/0, fun cleanup/1, fun(App) ->
        [
            {"no coverdata aborts", fun() ->
                ?assertThrow(
                    _,
                    rebar3_uncovered_cover:analyse_lines(
                        #{opts => #{coverage => eunit}, apps => [App]}
                    )
                )
            end},
            {"ct pattern does not match eunit file", fun() ->
                App1 = make_app(fixture_dir(~"cover_app")),
                ?assertThrow(
                    _,
                    rebar3_uncovered_cover:analyse_lines(
                        #{opts => #{coverage => ct}, apps => [App1]}
                    )
                )
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
