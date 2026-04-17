-module(rebar3_uncovered).

% Callbacks
-ignore_xref(init/1).
-export([init/1]).
-ignore_xref(do/1).
-export([do/1]).
-ignore_xref(format_error/1).
-export([format_error/1]).

-ifdef(TEST).
-export([parse_opts/1]).
-ignore_xref(parse_opts/1).
-endif.

%--- Callbacks -----------------------------------------------------------------

init(State) ->
    Provider =
        providers:create([
            {name, uncovered},
            {module, ?MODULE},
            {bare, true},
            {deps, [compile, app_discovery]},
            {example, "rebar3 uncovered"},
            {opts, opts()},
            {short_desc, "Report uncovered lines from tests"},
            {desc, desc()}
        ]),
    % elp:ignore W0017
    {ok, rebar_state:add_provider(State, Provider)}.

do(RebarState) ->
    % elp:ignore W0017
    {RawOpts, PathFilters} = rebar_state:command_parsed_args(RebarState),
    case proplists:get_value(help, RawOpts, false) of
        true ->
            print_help(),
            {ok, RebarState};
        false ->
            try run(RebarState, RawOpts, PathFilters) of
                ok -> {ok, RebarState}
            catch
                error:Reason -> {error, {?MODULE, Reason}}
            end
    end.

format_error({git_command_failed, N, Output}) ->
    io_lib:format("git exited ~b:~n~ts", [N, Output]);
format_error(git_not_found) ->
    "git binary not found in PATH";
format_error(git_timeout) ->
    "git command timed out";
format_error(Reason) ->
    io_lib:format("~p", [Reason]).

%--- Internal ------------------------------------------------------------------

run(RebarState, RawOpts, PathFilters) ->
    Opts = parse_opts(RawOpts),
    % elp:ignore W0017
    Apps = rebar_state:project_apps(RebarState),
    State = lists:foldl(
        fun(F, Acc) -> F(Acc) end,
        #{opts => Opts, apps => Apps, path_filters => PathFilters},
        [
            fun rebar3_uncovered_cover:analyse_lines/1,
            fun rebar3_uncovered_git:filter_uncovered/1,
            fun rebar3_uncovered_source:build_regions/1,
            fun rebar3_uncovered_format:format_lines/1
        ]
    ),
    % elp:ignore W0017
    print_output(State),
    ok.

print_help() ->
    getopt:usage(
        opts(), "rebar3 uncovered", "[-- path ...]", desc(), [], standard_io
    ).

opts() ->
    [
        {help, $h, "help", boolean, "Show this help"},
        {git, $g, "git", boolean, "Filter by git diff"},
        {git_scope, undefined, "git-scope", {string, "auto"},
            "Git diff scope: staged, unstaged, or a ref. Refs include all"
            " changes between where they diverged and HEAD. Default 'auto'"
            " uses trunk, resolved as the first of: origin/HEAD, origin/main,"
            " origin/master, HEAD."},
        {coverage, undefined, "coverage", {string, "aggregate"},
            "Coverage source: aggregate, eunit, ct"},
        {color, undefined, "color", {string, "auto"},
            "Color output: auto, always, never"},
        {format, $f, "format", {string, "human"}, "Output format: human, raw"},
        {context, $C, "context", {string, "2"},
            "Context lines: integer or 'all'"},
        {counts, undefined, "counts", {boolean, true}, "Show coverage counts"}
    ].

desc() ->
    ~"""
    Report uncovered lines from tests.

    Displays uncovered source lines with surrounding context and coverage counts.
    Supports filtering by git diff, coverage source, and file path.

    Positional arguments after -- are used as file or directory filters.
    """.

parse_opts(RawOpts) ->
    Defaults = #{
        coverage => aggregate,
        format => human,
        color => resolve_auto_color(),
        context => 2,
        counts => true,
        git => false,
        git_scope => auto,
        columns => resolve_columns()
    },
    Validated = maps:map(fun opt/2, maps:from_list(RawOpts)),
    resolve_git(maps:merge(Defaults, Validated)).

opt(coverage, "aggregate") -> aggregate;
opt(coverage, "eunit") -> eunit;
opt(coverage, "ct") -> ct;
opt(format, "human") -> human;
opt(format, "raw") -> raw;
opt(color, "always") -> true;
opt(color, "never") -> false;
opt(color, "auto") -> resolve_auto_color();
opt(context, "all") -> all;
opt(context, S) when is_list(S) -> opt(context, list_to_integer(S));
opt(context, N) when is_integer(N), N >= 0 -> N;
opt(counts, B) when is_boolean(B) -> B;
opt(git, B) when is_boolean(B) -> B;
opt(git_scope, "staged") -> staged;
opt(git_scope, "unstaged") -> unstaged;
opt(git_scope, "auto") -> auto;
opt(git_scope, Ref) when is_list(Ref) -> {ref, Ref};
opt(Name, Value) -> error({invalid_option, Name, Value}).

resolve_git(#{git := true, git_scope := Scope} = Opts) -> Opts#{git := Scope};
resolve_git(Opts) -> Opts.

resolve_auto_color() ->
    not is_list(os:getenv("NO_COLOR")) andalso
        io:columns() =/= {error, enotsup}.

resolve_columns() ->
    case io:columns() of
        {ok, Cols} -> Cols;
        {error, enotsup} -> 80
    end.

print_output(#{output := [], opts := #{format := raw}}) ->
    ok;
print_output(#{output := []}) ->
    % elp:ignore W0017
    rebar_api:console("No uncovered lines found", []);
print_output(#{output := Output}) ->
    % elp:ignore W0017
    rebar_api:console("~ts", [Output]).
