-module(rebar3_uncovered_format).

-export_type([format_opts/0]).

-type format_opts() :: #{
    format := human | raw,
    color := boolean(),
    context := non_neg_integer(),
    counts := boolean()
}.

% API
-export([format_lines/2]).

%--- API -----------------------------------------------------------------------

format_lines(Regions, #{format := raw} = Opts) ->
    format_raw(Regions, Opts);
format_lines(Regions, #{format := human} = Opts) ->
    format_human(Regions, Opts).

%--- Internal ------------------------------------------------------------------

format_raw(Regions, #{counts := ShowCounts}) ->
    [
        [
            File,
            ":",
            integer_to_list(N),
            "\t",
            raw_count(ShowCounts, Count),
            Source,
            "\n"
        ]
     || #{file := File, lines := Lines} <:- Regions,
        {N, Source, uncovered, Count} <:- Lines
    ].

raw_count(true, Count) -> [integer_to_list(Count), "\t"];
raw_count(false, _Count) -> "".

format_human(Regions, Opts) ->
    lists:join("\n", [format_region(R, Opts) || R <:- Regions]).

format_region(#{file := File, lines := Lines}, Opts) ->
    FormattedLines = [format_line(L, Opts) || L <:- Lines],
    [File, "\n" | FormattedLines].

format_line({N, Source, Status, Count}, #{color := Color, counts := ShowCounts}) ->
    LineNo = io_lib:format("~4w", [N]),
    CountStr = count_column(ShowCounts, Count),
    Marker = marker(Status),
    Line = [LineNo, " ", CountStr, Marker, " ", Source, "\n"],
    maybe_colorize(Line, Status, Color).

count_column(true, Count) -> [format_count(Count), " "];
count_column(false, _Count) -> "".

format_count(none) -> "     ";
format_count(N) -> io_lib:format("~5w", [N]).

marker(uncovered) -> ">";
marker(covered) -> " ".

maybe_colorize(Line, uncovered, true) -> ["\e[31m", Line, "\e[0m"];
maybe_colorize(Line, _, _) -> Line.
