-module(rebar3_uncovered_format).

-export_type([format_opts/0]).

-type format_opts() :: #{
    format := human | raw,
    color := boolean(),
    context := non_neg_integer()
}.

% API
-export([format_lines/2]).

%--- API -----------------------------------------------------------------------

format_lines(Regions, #{format := raw}) ->
    format_raw(Regions);
format_lines(Regions, #{format := human} = Opts) ->
    format_human(Regions, Opts).

%--- Internal ------------------------------------------------------------------

format_raw(Regions) ->
    [
        [File, ":", integer_to_list(N), "\t", Source, "\n"]
     || #{file := File, lines := Lines} <:- Regions,
        {N, Source, uncovered} <:- Lines
    ].

format_human(Regions, Opts) ->
    lists:join("\n", [format_region(R, Opts) || R <:- Regions]).

format_region(#{file := File, lines := Lines}, Opts) ->
    FormattedLines = [format_line(L, Opts) || L <:- Lines],
    [File, "\n" | FormattedLines].

format_line({N, Source, Status}, #{color := Color}) ->
    LineNo = io_lib:format("~4w", [N]),
    Marker = marker(Status),
    Line = [LineNo, " ", Marker, " ", Source, "\n"],
    maybe_colorize(Line, Status, Color).

marker(uncovered) -> ">";
marker(covered) -> " ".

maybe_colorize(Line, uncovered, true) -> ["\e[31m", Line, "\e[0m"];
maybe_colorize(Line, _, _) -> Line.
