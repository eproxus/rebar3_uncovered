-module(rebar3_uncovered_cover).

-export_type([line_map/0]).

-type line_info() :: #{count := non_neg_integer(), show => true}.
-type line_map() :: #{file:filename() => #{pos_integer() => line_info()}}.

% API
-export([analyse_lines/1]).

%--- API -----------------------------------------------------------------------

analyse_lines(#{opts := #{coverage := Source}, apps := Apps} = S) ->
    {Pattern, Name} = coverdata_pattern(Source),
    case coverdata_files(Pattern, Apps) of
        [] ->
            % elp:ignore W0017
            rebar_api:abort(
                "No ~s coverdata files found. Did you run tests?", [Name]
            );
        Files ->
            SourceDirs = source_dirs(Apps),
            {ok, Cwd} = file:get_cwd(),
            S#{files => import_and_analyse(Files, SourceDirs, Cwd)}
    end.

import_and_analyse(Files, SourceDirs, Cwd) ->
    silence_cover(fun() ->
        lists:foreach(fun cover:import/1, Files),
        Modules = imported_modules(),
        lists:foldl(
            fun(M, Acc) ->
                maps:merge(Acc, module_lines(M, SourceDirs, Cwd))
            end,
            #{},
            Modules
        )
    end).

%--- Internal ------------------------------------------------------------------

module_lines(Mod, SourceDirs, Cwd) ->
    case find_source(Mod, SourceDirs) of
        {ok, AbsFile} ->
            File = make_relative(AbsFile, Cwd),
            #{File => analyse(Mod)};
        error ->
            #{}
    end.

analyse(Mod) ->
    {ok, [_ | _] = Analysis} = cover:analyse(Mod, coverage, line),
    #{Line => line_info(Cov) || {{_, Line}, {Cov, _}} <:- Analysis}.

line_info(0) -> #{count => 0, show => true};
line_info(C) -> #{count => C}.

source_dirs(Apps) ->
    % elp:ignore W0017
    [filename:join(rebar_app_info:dir(App), "src") || App <:- Apps].

silence_cover(Fun) ->
    Pid = cover_pid(cover:start()),
    {group_leader, OldGL} = erlang:process_info(Pid, group_leader),
    {ok, Null} = file:open("/dev/null", [write]),
    erlang:group_leader(Null, Pid),
    try
        Fun()
    after
        erlang:group_leader(OldGL, Pid),
        file:close(Null)
    end.

cover_pid({ok, Pid}) -> Pid;
cover_pid({error, {already_started, Pid}}) -> Pid.

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

make_relative(Path, Base) ->
    case string:prefix(Path, Base ++ "/") of
        nomatch -> Path;
        Relative -> Relative
    end.
