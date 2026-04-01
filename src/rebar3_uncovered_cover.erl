-module(rebar3_uncovered_cover).

-export_type([uncovered_line/0]).

-type uncovered_line() :: #{
    module := module(),
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
            lists:flatmap(fun module_uncovered/1, Modules)
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

module_uncovered(Mod) ->
    module_uncovered(Mod, cover:analyse(Mod, coverage, line)).

module_uncovered(Mod, {ok, Analysis}) ->
    [#{module => Mod, line => Line} || {{_, Line}, {0, _}} <:- Analysis];
module_uncovered(_Mod, {error, _}) ->
    [].
