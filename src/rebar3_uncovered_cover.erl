-module(rebar3_uncovered_cover).

-export_type([uncovered_line/0, line_counts/0]).

-type uncovered_line() :: #{
    module := module(),
    line := pos_integer()
}.

-type line_counts() :: #{module() => #{pos_integer() => non_neg_integer()}}.

% API
-export([uncovered_lines/2]).

%--- API -----------------------------------------------------------------------

uncovered_lines(#{coverage := Source}, Apps) ->
    {Pattern, Name} = coverdata_pattern(Source),
    case coverdata_files(Pattern, Apps) of
        [] ->
            % elp:ignore W0017
            rebar_api:warn("No ~s coverdata files found", [Name]),
            {[], #{}};
        Files ->
            silence_cover(fun() ->
                lists:foreach(fun cover:import/1, Files),
                Modules = imported_modules(),
                Uncovered = lists:flatmap(fun module_uncovered/1, Modules),
                Counts = lists:foldl(
                    fun(M, Acc) -> Acc#{M => module_counts(M)} end, #{}, Modules
                ),
                {Uncovered, Counts}
            end)
    end.

%--- Internal ------------------------------------------------------------------

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

module_uncovered(Mod) ->
    module_uncovered(Mod, cover:analyse(Mod, coverage, line)).

module_uncovered(Mod, {ok, Analysis}) ->
    [
        #{module => Mod, line => Line}
     || {{_, Line}, {Cov, _}} <:- Analysis, Cov =:= 0
    ];
module_uncovered(_Mod, {error, _}) ->
    [].

module_counts(Mod) -> analyse_counts(cover:analyse(Mod, coverage, line)).

analyse_counts({ok, Analysis}) ->
    #{Line => Cov || {{_, Line}, {Cov, _}} <:- Analysis};
analyse_counts({error, _}) ->
    #{}.
