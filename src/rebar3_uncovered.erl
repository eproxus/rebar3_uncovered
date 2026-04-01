-module(rebar3_uncovered).

% Callbacks
-ignore_xref(init/1).
-export([init/1]).
-ignore_xref(do/1).
-export([do/1]).
-ignore_xref(format_error/1).
-export([format_error/1]).

%--- Callbacks -----------------------------------------------------------------

-spec init(term()) -> {ok, term()}.
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

-spec do(term()) -> {ok, term()}.
do(State) ->
    % elp:ignore W0017
    {Opts, PathFilters} = rebar_state:command_parsed_args(State),
    Coverage = validate_coverage(Opts),
    Format = validate_format(Opts),
    Color = resolve_color(Opts),
    Context = proplists:get_value(context, Opts, 2),
    GitMode = resolve_git(Opts),

    % elp:ignore W0017
    Apps = rebar_state:project_apps(State),
    Uncovered0 = rebar3_uncovered_cover:uncovered_lines(Coverage, Apps),
    Uncovered1 = maybe_filter_git(Uncovered0, GitMode),
    Uncovered2 = filter_paths(Uncovered1, PathFilters),

    Regions = rebar3_uncovered_source:read_regions(Uncovered2, Context),
    case
        rebar3_uncovered_format:format_lines(
            Regions, #{format => Format, color => Color, context => Context}
        )
    of
        [] -> ok;
        % elp:ignore W0017
        Output -> rebar_api:console("~s", [Output])
    end,
    {ok, State}.

-spec format_error(term()) -> iolist().
format_error(Reason) -> io_lib:format("~p", [Reason]).

%--- Internal ------------------------------------------------------------------

opts() ->
    [
        {git, $g, "git", boolean, "Only show uncovered lines in git diff"},
        {coverage, undefined, "coverage", {string, "aggregate"},
            "Coverage source: aggregate, eunit, ct"},
        {color, undefined, "color", {string, "auto"},
            "Color output: auto, always, never"},
        {format, $f, "format", {string, "human"}, "Output format: human, raw"},
        {context, $C, "context", {integer, 2},
            "Number of surrounding context lines"}
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

-spec validate_coverage(proplists:proplist()) -> aggregate | eunit | ct.
validate_coverage(Opts) ->
    validate_coverage_value(proplists:get_value(coverage, Opts, "aggregate")).

validate_coverage_value("aggregate") -> aggregate;
validate_coverage_value("eunit") -> eunit;
validate_coverage_value("ct") -> ct;
validate_coverage_value(Other) -> error({invalid_option, coverage, Other}).

-spec validate_format(proplists:proplist()) -> human | raw.
validate_format(Opts) ->
    validate_format_value(proplists:get_value(format, Opts, "human")).

validate_format_value("human") -> human;
validate_format_value("raw") -> raw;
validate_format_value(Other) -> error({invalid_option, format, Other}).

-spec resolve_git(proplists:proplist()) -> false | all.
resolve_git(Opts) -> resolve_git_value(proplists:get_value(git, Opts)).

resolve_git_value(true) -> all;
resolve_git_value(_) -> false.

-spec resolve_color(proplists:proplist()) -> boolean().
resolve_color(Opts) ->
    resolve_color_value(proplists:get_value(color, Opts, "auto")).

resolve_color_value("always") ->
    true;
resolve_color_value("never") ->
    false;
resolve_color_value("auto") ->
    not is_list(os:getenv("NO_COLOR")) andalso
        io:columns() =/= {error, enotsup}.

-spec maybe_filter_git(
    [rebar3_uncovered_cover:uncovered_line()], false | all
) -> [rebar3_uncovered_cover:uncovered_line()].
maybe_filter_git(Uncovered, false) ->
    Uncovered;
maybe_filter_git(Uncovered, Mode) ->
    Changed = rebar3_uncovered_git:changed_lines(Mode),
    [
        Line
     || #{file := File, line := LineNo} = Line <:- Uncovered,
        lists:member(LineNo, maps:get(File, Changed, []))
    ].

-spec filter_paths(
    [rebar3_uncovered_cover:uncovered_line()], [string()]
) -> [rebar3_uncovered_cover:uncovered_line()].
filter_paths(Uncovered, []) ->
    Uncovered;
filter_paths(Uncovered, Filters) ->
    [
        Line
     || #{file := File} = Line <:- Uncovered, matches_any_filter(File, Filters)
    ].

-spec matches_any_filter(file:filename(), [string()]) -> boolean().
matches_any_filter(File, Filters) ->
    lists:any(fun(Filter) -> lists:prefix(Filter, File) end, Filters).
