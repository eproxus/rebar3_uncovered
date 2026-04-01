-module(rebar3_uncovered).

% Callbacks
-ignore_xref(init/1).
-export([init/1]).
-ignore_xref(do/1).
-export([do/1]).
-ignore_xref(format_error/1).
-export([format_error/1]).

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

do(State) ->
    % elp:ignore W0017
    {Opts, PathFilters} = rebar_state:command_parsed_args(State),
    Coverage = opt(coverage, Opts),
    Format = opt(format, Opts),
    Color = opt(color, Opts),
    Context = opt(context, Opts),
    ShowCounts = opt(counts, Opts),
    GitMode =
        case proplists:get_value(git, Opts) of
            true -> opt(git_scope, Opts);
            _ -> false
        end,

    % elp:ignore W0017
    Apps = rebar_state:project_apps(State),
    {Uncovered0, Counts} = rebar3_uncovered_cover:uncovered_lines(
        Coverage, Apps
    ),
    Uncovered1 = rebar3_uncovered_source:resolve_files(Uncovered0, Apps),
    Uncovered2 = maybe_filter_git(Uncovered1, GitMode),
    Uncovered3 = filter_paths(Uncovered2, PathFilters),

    Regions = rebar3_uncovered_source:read_regions(Uncovered3, Context, Counts),
    FormatOpts = #{
        format => Format,
        color => Color,
        context => Context,
        counts => ShowCounts,
        columns => resolve_columns()
    },
    case rebar3_uncovered_format:format_lines(Regions, FormatOpts) of
        [] -> ok;
        % elp:ignore W0017
        Output -> rebar_api:console("~ts", [Output])
    end,
    {ok, State}.

format_error(Reason) -> io_lib:format("~p", [Reason]).

%--- Internal ------------------------------------------------------------------

opts() ->
    [
        {git, $g, "git", boolean, "Filter by git diff"},
        {git_scope, undefined, "git-scope", {string, "all"},
            "Git diff scope: staged, all, unstaged"},
        {coverage, undefined, "coverage", {string, "aggregate"},
            "Coverage source: aggregate, eunit, ct"},
        {color, undefined, "color", {string, "auto"},
            "Color output: auto, always, never"},
        {format, $f, "format", {string, "human"}, "Output format: human, raw"},
        {context, $C, "context", {integer, 2},
            "Number of surrounding context lines"},
        {counts, undefined, "counts", {boolean, true}, "Show coverage counts"}
    ].

desc() ->
    ~"""
    Report uncovered lines from tests.

    Displays source code of uncovered lines with syntax
    highlighting and surrounding context. Supports
    filtering by git diff, coverage source, and file path
    filters.

    Positional arguments are used as file or directory
    filters.
    """.

opt(Name, Opts) -> opt_value(Name, proplists:get_value(Name, Opts)).

opt_value(coverage, undefined) -> aggregate;
opt_value(coverage, "aggregate") -> aggregate;
opt_value(coverage, "eunit") -> eunit;
opt_value(coverage, "ct") -> ct;
opt_value(format, undefined) -> human;
opt_value(format, "human") -> human;
opt_value(format, "raw") -> raw;
opt_value(color, undefined) -> resolve_auto_color();
opt_value(color, "always") -> true;
opt_value(color, "never") -> false;
opt_value(color, "auto") -> resolve_auto_color();
opt_value(context, undefined) -> 2;
opt_value(context, N) when is_integer(N), N >= 0 -> N;
opt_value(counts, undefined) -> true;
opt_value(counts, B) when is_boolean(B) -> B;
opt_value(git_scope, undefined) -> all;
opt_value(git_scope, "staged") -> staged;
opt_value(git_scope, "all") -> all;
opt_value(git_scope, "unstaged") -> unstaged;
opt_value(Name, Value) -> error({invalid_option, Name, Value}).

resolve_auto_color() ->
    os:getenv("NO_COLOR") =:= false andalso io:columns() =/= {error, enotsup}.

resolve_columns() ->
    case io:columns() of
        {ok, Cols} -> Cols;
        {error, enotsup} -> 80
    end.

maybe_filter_git(Uncovered, false) ->
    Uncovered;
maybe_filter_git(Uncovered, Mode) ->
    Changed = rebar3_uncovered_git:changed_lines(Mode),
    [
        Line
     || #{file := File, line := LineNo} = Line <:- Uncovered,
        lists:member(LineNo, maps:get(File, Changed, []))
    ].

filter_paths(Uncovered, []) ->
    Uncovered;
filter_paths(Uncovered, Filters) ->
    [
        Line
     || #{file := File} = Line <:- Uncovered, matches_any_filter(File, Filters)
    ].

matches_any_filter(File, Filters) ->
    lists:any(fun(Filter) -> lists:prefix(Filter, File) end, Filters).
