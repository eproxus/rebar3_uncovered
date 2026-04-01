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

uncovered_lines(Source, Apps) ->
    {Pattern, Name} = coverdata_pattern(Source),
    case coverdata_files(Pattern, Apps) of
        [] ->
            % elp:ignore W0017
            rebar_api:warn("No ~s coverdata files found", [Name]),
            [];
        Files ->
            lists:foreach(fun cover:import/1, Files),
            Modules = imported_modules(),
            SourceDirs = source_dirs(Apps),
            lists:flatmap(
                fun(Mod) -> module_uncovered(Mod, SourceDirs) end, Modules
            )
    end.

%--- Internal ------------------------------------------------------------------

imported_modules() ->
    Modules = cover:imported_modules(),
    true = is_list(Modules),
    Modules.

coverdata_files(Pattern, [App | _]) ->
    % elp:ignore W0017
    Dir = rebar_app_info:dir(App),
    CoverDir = filename:join([Dir, "_build", "test", "cover"]),
    filelib:wildcard(filename:join(CoverDir, Pattern)).

coverdata_pattern(aggregate) -> {"*.coverdata", "aggregate"};
coverdata_pattern(eunit) -> {"eunit.coverdata", "EUnit"};
coverdata_pattern(ct) -> {"ct.coverdata", "Common Test"}.

source_dirs(Apps) ->
    % elp:ignore W0017
    [filename:join(rebar_app_info:dir(App), "src") || App <:- Apps].

module_uncovered(Mod, SourceDirs) ->
    module_uncovered(Mod, SourceDirs, cover:analyse(Mod, coverage, line)).

module_uncovered(Mod, SourceDirs, {ok, Analysis}) ->
    module_uncovered_source(Mod, Analysis, find_source(Mod, SourceDirs));
module_uncovered(_Mod, _SourceDirs, {error, _}) ->
    [].

module_uncovered_source(Mod, Analysis, {ok, File}) ->
    [
        #{module => Mod, file => File, line => Line}
     || {{_, Line}, {0, _}} <- Analysis
    ];
module_uncovered_source(_Mod, _Analysis, error) ->
    [].

find_source(Mod, SourceDirs) ->
    Filename = atom_to_list(Mod) ++ ".erl",
    Paths = [
        Path
     || Dir <:- SourceDirs,
        Path <:- [filename:join(Dir, Filename)],
        filelib:is_file(Path)
    ],
    find_source_result(Paths).

find_source_result([File | _]) -> {ok, File};
find_source_result([]) -> error.
