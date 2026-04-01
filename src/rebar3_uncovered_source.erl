-module(rebar3_uncovered_source).

-export_type([uncovered_region/0]).

-type uncovered_region() :: #{
    file := file:filename(),
    lines := [{pos_integer(), binary(), covered | uncovered}]
}.

% API
-export([read_regions/2]).

%--- API -----------------------------------------------------------------------

-spec read_regions(
    [rebar3_uncovered_cover:uncovered_line()], non_neg_integer()
) -> [uncovered_region()].
read_regions(UncoveredLines, Context) ->
    Grouped = group_by_file(UncoveredLines),
    lists:flatmap(
        fun({File, Lines}) -> file_regions(File, Lines, Context) end,
        maps:to_list(Grouped)
    ).

%--- Internal ------------------------------------------------------------------

-spec group_by_file([rebar3_uncovered_cover:uncovered_line()]) ->
    #{file:filename() => [pos_integer()]}.
group_by_file(Lines) ->
    lists:foldl(
        fun(#{file := File, line := Line}, Acc) ->
            maps:update_with(File, fun(Ls) -> [Line | Ls] end, [Line], Acc)
        end,
        #{},
        Lines
    ).

-spec file_regions(file:filename(), [pos_integer()], non_neg_integer()) ->
    [uncovered_region()].
file_regions(File, UncoveredLines, Context) ->
    case file:read_file(File) of
        {ok, Content} ->
            AllLines = binary:split(Content, ~"\n", [global]),
            Sorted = lists:usort(UncoveredLines),
            Groups = group_consecutive(Sorted, Context),
            [build_region(File, Group, AllLines) || Group <:- Groups];
        {error, _} ->
            []
    end.

-spec group_consecutive([pos_integer()], non_neg_integer()) ->
    [[pos_integer()]].
group_consecutive([], _Context) ->
    [];
group_consecutive([First | Rest], Context) ->
    group_consecutive(Rest, Context, [First], []).

-spec group_consecutive(
    [pos_integer()], non_neg_integer(), [pos_integer()], [[pos_integer()]]
) -> [[pos_integer()]].
group_consecutive([], _Context, Current, Acc) ->
    lists:reverse([lists:reverse(Current) | Acc]);
group_consecutive([Line | Rest], Context, [Prev | _] = Current, Acc) when
    Line - Prev =< Context * 2
->
    group_consecutive(Rest, Context, [Line | Current], Acc);
group_consecutive([Line | Rest], Context, Current, Acc) ->
    group_consecutive(Rest, Context, [Line], [lists:reverse(Current) | Acc]).

-spec build_region(file:filename(), [pos_integer()], [binary()]) ->
    uncovered_region().
build_region(File, UncoveredLines, AllLines) ->
    First = hd(UncoveredLines),
    Last = lists:last(UncoveredLines),
    #{
        file => File,
        lines => [
            {N, lists:nth(N, AllLines), line_status(N, UncoveredLines)}
         || N <:- lists:seq(First, Last)
        ]
    }.

line_status(Line, UncoveredLines) ->
    case lists:member(Line, UncoveredLines) of
        true -> uncovered;
        false -> covered
    end.
