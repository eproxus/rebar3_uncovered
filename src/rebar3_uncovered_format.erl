-module(rebar3_uncovered_format).

% API
-export([format_lines/1]).

%--- API -----------------------------------------------------------------------

format_lines(#{regions := Regions, opts := #{format := raw} = Opts} = S) ->
    S#{output => format_raw(Regions, Opts)};
format_lines(#{regions := Regions, opts := #{format := human} = Opts} = S) ->
    S#{output => format_human(Regions, Opts)}.

%--- Internal ------------------------------------------------------------------

format_raw(Regions, #{counts := ShowCounts}) ->
    lists:join("\n", [
        format_raw_line(File, L, ShowCounts)
     || #{file := File, lines := Lines} <:- Regions,
        L <:- Lines
    ]).

format_raw_line(File, {N, Source, Status, Count}, ShowCounts) ->
    [
        File,
        raw_sep(Status),
        integer_to_list(N),
        " ",
        raw_count(ShowCounts, Count),
        Source
    ].

raw_sep(uncovered) -> ":";
raw_sep(covered) -> ":".

raw_count(true, none) -> "- ";
raw_count(true, Count) -> [integer_to_list(Count), " "];
raw_count(false, _Count) -> "".

format_human(Regions, Opts) ->
    Widths = compute_widths(Regions),
    Groups = group_by_file(Regions),
    lists:join("\n", [
        format_file_group(File, Rs, Opts, Widths)
     || {File, Rs} <:- Groups
    ]).

format_file_group(
    File,
    Regions,
    #{counts := ShowCounts, columns := Cols, color := C} = Opts,
    #{line_width := LW} = Widths
) ->
    CW = count_col_width(ShowCounts, Widths),
    Sep = fg(~"│", border, C),
    Blocks = [
        [format_line(L, Opts, Widths) || L <:- Lines]
     || #{lines := Lines} <:- Regions
    ],
    Body = lists:join(collapse_line(LW, CW, C), Blocks),
    [
        border(~"╤", ~"═", LW, CW, Cols, C),
        "\n",
        header(File, LW, CW, Sep),
        "\n",
        border(~"╪", ~"═", LW, CW, Cols, C),
        "\n",
        Body,
        border(~"┴", ~"─", LW, CW, Cols, C)
    ].

group_by_file([]) -> [];
group_by_file([#{file := F} = R | Rest]) -> group_by_file(Rest, F, [R], []).

group_by_file([], File, Current, Acc) ->
    lists:reverse([{File, lists:reverse(Current)} | Acc]);
group_by_file([#{file := File} = R | Rest], File, Current, Acc) ->
    group_by_file(Rest, File, [R | Current], Acc);
group_by_file([#{file := F} = R | Rest], PrevFile, Current, Acc) ->
    group_by_file(Rest, F, [R], [{PrevFile, lists:reverse(Current)} | Acc]).

collapse_line(LW, CW, C) ->
    DotSep = fg(~"┊", border, C),
    Ellipsis = dim(~"⋮", C),
    [
        " ",
        lists:duplicate(LW - 1, " "),
        Ellipsis,
        " ",
        DotSep,
        collapse_count(CW, DotSep),
        "\n"
    ].

collapse_count(0, _DotSep) -> "";
collapse_count(CW, DotSep) -> [lists:duplicate(CW, " "), DotSep].

border(Joint, Bar, LW, CW, Cols, C) ->
    {CountPart, CountWidth} = count_border(CW, Joint, Bar),
    Rest = max(0, Cols - LW - 3 - CountWidth),
    fg(
        [binary:copy(Bar, LW + 2), Joint, CountPart, binary:copy(Bar, Rest)],
        border,
        C
    ).

count_border(0, _Joint, _Bar) -> {"", 0};
count_border(CW, Joint, Bar) -> {[binary:copy(Bar, CW), Joint], CW + 1}.

header(File, LW, CW, Sep) ->
    [lists:duplicate(LW + 2, " "), Sep, count_header(CW, Sep), " ", File].

count_header(0, _Sep) -> "";
count_header(CW, Sep) -> [lists:duplicate(CW, " "), Sep].

format_line(
    {N, Source, Status, Count},
    #{columns := Cols, color := C} = Opts,
    #{line_width := LW} = W
) ->
    Sep = fg(~"│", border, C),
    {CP, CC, CG} = count_parts(Count, Status, Sep, C, Opts, W),
    Gutter = LW + 2 + 1 + CG,
    Prefix = [line_number(N, LW, Status, C), Sep | CP],
    Cont = [lists:duplicate(LW + 2, " "), Sep | CC],
    format_wrapped(
        wrap_source(Source, max(1, Cols - Gutter - 1)),
        Prefix,
        Cont,
        Status,
        Gutter,
        Cols,
        C
    ).

count_parts(_Count, _Status, _Sep, _C, #{counts := false}, _W) ->
    {[], [], 0};
count_parts(Count, Status, Sep, C, _Opts, #{count_width := CW}) ->
    {
        [count_cell(Count, CW, Status, C), Sep],
        [lists:duplicate(CW + 2, " "), Sep],
        CW + 2 + 1
    }.

line_number(N, LW, uncovered, C) -> bold(line_number_pad(N, LW), C);
line_number(N, LW, _Status, _C) -> line_number_pad(N, LW).

line_number_pad(N, LW) -> [" ", pad(integer_to_list(N), LW, right), " "].

count_cell(Count, CW, uncovered, C) ->
    fg(bold([" ", format_count(Count, CW), " "], C), {uncovered, count}, C);
count_cell(Count, CW, covered, C) ->
    fg([" ", format_count(Count, CW), " "], {covered, count}, C).

format_count(none, Width) -> lists:duplicate(Width, $\s);
format_count(N, Width) -> pad(integer_to_list(N), Width, left).

count_col_width(false, _Widths) -> 0;
count_col_width(true, #{count_width := CW}) -> CW + 2.

format_wrapped([First | Rest], Prefix, Cont, uncovered, Gutter, Cols, true) ->
    FW = Cols - Gutter,
    [
        bg_line(Prefix, First, FW),
        "\n"
        | [[bg_line(Cont, C, FW), "\n"] || C <:- Rest]
    ];
format_wrapped([First | Rest], Prefix, Cont, _Status, _Gutter, _Cols, _C) ->
    [Prefix, " ", First, "\n" | [[Cont, " ", C, "\n"] || C <:- Rest]].

bg_line(Prefix, Chunk, FillWidth) ->
    Width = max(iolist_size(Chunk) + 1, FillWidth),
    bg([Prefix, pad([" ", Chunk], Width, left)], {uncovered, bg}).

wrap_source(Source, Width) when Width > 0 ->
    case iolist_size(Source) > Width of
        false ->
            [Source];
        true ->
            Bin = iolist_to_binary(Source),
            wrap_chunks(Bin, Width, [])
    end;
wrap_source(Source, _Width) ->
    [Source].

wrap_chunks(<<>>, _Width, Acc) ->
    lists:reverse(Acc);
wrap_chunks(Bin, Width, Acc) ->
    case Bin of
        <<Chunk:Width/binary, Rest/binary>> ->
            wrap_chunks(Rest, Width, [Chunk | Acc]);
        _ ->
            lists:reverse([Bin | Acc])
    end.

% Colors

color(border) -> {50, 70, 120};
color({uncovered, count}) -> {255, 120, 100};
color({covered, count}) -> {100, 230, 100};
color({uncovered, bg}) -> {60, 20, 20}.

% Styling helpers

pad(Text, Width, right) ->
    io_lib:format("~*s", [Width, iolist_to_binary(Text)]);
pad(Text, Width, left) ->
    io_lib:format("~-*s", [Width, iolist_to_binary(Text)]).

bold(Text, true) -> [~"\e[1m", Text];
bold(Text, false) -> Text.

dim(Text, true) -> [~"\e[2m", Text, ~"\e[22m"];
dim(Text, false) -> Text.

fg(Text, _Name, false) ->
    Text;
fg(Text, Name, true) ->
    {R, G, B} = color(Name),
    [io_lib:format(~"\e[38;2;~B;~B;~Bm", [R, G, B]), Text, ~"\e[39m"].

bg(Text, Name) ->
    {R, G, B} = color(Name),
    [io_lib:format(~"\e[48;2;~B;~B;~Bm", [R, G, B]), Text, ~"\e[0m"].

compute_widths(Regions) ->
    {MaxLine, MaxCount} = lists:foldl(
        fun(#{lines := Lines}, Acc) ->
            lists:foldl(
                fun({N, _, _, Count}, {ML, MC}) ->
                    {max(N, ML), max_count(Count, MC)}
                end,
                Acc,
                Lines
            )
        end,
        {0, 0},
        Regions
    ),
    #{line_width => num_width(MaxLine), count_width => num_width(MaxCount)}.

max_count(none, Acc) -> Acc;
max_count(N, Acc) -> max(N, Acc).

num_width(0) -> 1;
num_width(N) -> length(integer_to_list(N)).
