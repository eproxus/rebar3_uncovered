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

-spec format_lines([rebar3_uncovered_source:uncovered_region()], format_opts()) ->
    iodata().
format_lines(Regions, #{format := raw}) ->
    format_raw(Regions);
format_lines(Regions, #{format := human} = Opts) ->
    format_human(Regions, Opts).

%--- Internal ------------------------------------------------------------------

-spec format_raw([rebar3_uncovered_source:uncovered_region()]) -> iodata().
format_raw(Regions) ->
    [
        [File, ":", integer_to_list(N), "\t", Source, "\n"]
     || #{file := File, lines := Lines} <- Regions,
        {N, Source, uncovered} <- Lines
    ].

-spec format_human([rebar3_uncovered_source:uncovered_region()], format_opts()) ->
    iodata().
format_human(Regions, Opts) ->
    lists:join("\n", [format_region(R, Opts) || R <- Regions]).

-spec format_region(rebar3_uncovered_source:uncovered_region(), format_opts()) ->
    iodata().
format_region(#{file := File, lines := Lines}, Opts) ->
    FormattedLines = [format_line(L, Opts) || L <- Lines],
    [File, "\n" | FormattedLines].

-spec format_line(
    {pos_integer(), binary(), covered | uncovered}, format_opts()
) -> iodata().
format_line({N, Source, Status}, #{color := Color}) ->
    LineNo = io_lib:format("~4w", [N]),
    Marker = marker(Status),
    Line = [LineNo, " ", Marker, " ", Source, "\n"],
    maybe_colorize(Line, Status, Color).

-spec marker(covered | uncovered) -> string().
marker(uncovered) -> ">";
marker(covered) -> " ".

-spec maybe_colorize(iodata(), covered | uncovered, boolean()) -> iodata().
maybe_colorize(Line, uncovered, true) -> ["\e[31m", Line, "\e[0m"];
maybe_colorize(Line, _, _) -> Line.
