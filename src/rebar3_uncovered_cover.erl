-module(rebar3_uncovered_cover).

-export_type([uncovered_line/0]).

-type uncovered_line() :: #{
    module := module(),
    file := file:filename(),
    line := pos_integer()
}.

% API
-export([uncovered_lines/2]).

%--- API -----------------------------------------------------------------------

-spec uncovered_lines(Source, Apps) -> [uncovered_line()] when
    Source :: aggregate | eunit | ct,
    Apps :: [term()].
uncovered_lines(Source, Apps) ->
    Files = coverdata_files(Source, Apps),
    lists:foreach(fun cover:import/1, Files),
    Modules = cover:imported_modules(),
    SourceDirs = source_dirs(Apps),
    lists:flatmap(
        fun(Mod) -> module_uncovered(Mod, SourceDirs) end, Modules
    ).

%--- Internal ------------------------------------------------------------------

-spec coverdata_files(aggregate | eunit | ct, [term()]) -> [file:filename()].
coverdata_files(_Source, [App | _]) ->
    % elp:ignore W0017
    Dir = rebar_app_info:dir(App),
    CoverDir = filename:join([Dir, "_build", "test", "cover"]),
    filelib:wildcard(filename:join(CoverDir, "*.coverdata")).

-spec source_dirs([term()]) -> [file:filename()].
% elp:ignore W0017
source_dirs(Apps) ->
    [filename:join(rebar_app_info:dir(App), "src") || App <- Apps].

-spec module_uncovered(module(), [file:filename()]) -> [uncovered_line()].
module_uncovered(Mod, SourceDirs) ->
    module_uncovered(Mod, SourceDirs, cover:analyse(Mod, coverage, line)).

module_uncovered(Mod, SourceDirs, {ok, Analysis}) ->
    module_uncovered_source(Mod, Analysis, find_source(Mod, SourceDirs));
module_uncovered(_Mod, _SourceDirs, {error, _}) ->
    [].

module_uncovered_source(Mod, Analysis, {ok, File}) ->
    [
        #{module => Mod, file => File, line => Line}
     || {{_, Line}, {0, N}} <- Analysis, N > 0
    ];
module_uncovered_source(_Mod, _Analysis, error) ->
    [].

-spec find_source(module(), [file:filename()]) -> {ok, file:filename()} | error.
find_source(Mod, SourceDirs) ->
    Filename = atom_to_list(Mod) ++ ".erl",
    Paths = [
        Path
     || Dir <- SourceDirs,
        Path <- [filename:join(Dir, Filename)],
        filelib:is_file(Path)
    ],
    find_source_result(Paths).

find_source_result([File | _]) -> {ok, File};
find_source_result([]) -> error.
