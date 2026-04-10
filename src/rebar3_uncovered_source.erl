-module(rebar3_uncovered_source).

-export_type([uncovered_region/0]).

-type uncovered_region() :: #{
    file := file:filename(),
    lines := [
        {pos_integer(), binary(), covered | uncovered, non_neg_integer() | none}
    ]
}.

% API
-export([build_regions/1]).

%--- API -----------------------------------------------------------------------

build_regions(#{opts := #{context := Context}} = S) ->
    Filtered = filter_paths(S),
    Enriched = maps:map(fun enrich_file/2, Filtered),
    Regions = lists:flatmap(
        fun({File, FileLines}) ->
            build_file_regions(File, FileLines, Context)
        end,
        maps:to_list(Enriched)
    ),
    S#{files := Enriched, regions => Regions}.

%--- Internal ------------------------------------------------------------------

filter_paths(#{files := Files, path_filters := []}) ->
    Files;
filter_paths(#{files := Files, path_filters := Filters}) ->
    maps:filter(fun(File, _) -> matches_any_filter(File, Filters) end, Files).

matches_any_filter(File, Filters) ->
    lists:any(fun(Filter) -> lists:prefix(Filter, File) end, Filters).

enrich_file(File, FileLines) ->
    case file:read_file(File) of
        {ok, Content} ->
            SourceLines = binary:split(Content, ~"\n", [global]),
            AllLines = source_lines(SourceLines, 1, #{}),
            mapz:deep_merge(AllLines, FileLines);
        {error, _} ->
            FileLines
    end.

source_lines([], _, Acc) ->
    Acc;
source_lines([Src | Rest], N, Acc) ->
    source_lines(Rest, N + 1, Acc#{N => #{source => Src}}).

build_file_regions(File, FileLines, all) ->
    build_file_regions(File, FileLines, maps:size(FileLines));
build_file_regions(File, FileLines, Context) ->
    Anchors = [N || N := Val <:- FileLines, is_anchor(Val)],
    Sorted = lists:usort(Anchors),
    Groups = group_consecutive(Sorted, Context),
    FileLength = maps:size(FileLines),
    [
        build_region(File, Group, FileLength, Context, FileLines)
     || Group <:- Groups
    ].

is_anchor(#{show := true}) -> true;
is_anchor(_) -> false.

build_region(File, UncoveredLines, FileLength, Context, FileLines) ->
    First = max(1, hd(UncoveredLines) - Context),
    Last = min(FileLength, lists:last(UncoveredLines) + Context),
    #{
        file => File,
        lines => region_lines(First, Last, UncoveredLines, FileLines)
    }.

region_lines(N, Last, _, _) when N > Last ->
    [];
region_lines(N, Last, Uncovered, FileLines) ->
    #{source := Src} = Info = maps:get(N, FileLines),
    Count = maps:get(count, Info, none),
    [
        {N, Src, line_status(N, Uncovered), Count}
        | region_lines(N + 1, Last, Uncovered, FileLines)
    ].

line_status(Line, UncoveredLines) ->
    case lists:member(Line, UncoveredLines) of
        true -> uncovered;
        false -> covered
    end.

group_consecutive([], _Context) ->
    [];
group_consecutive([First | Rest], Context) ->
    group_consecutive(Rest, Context, [First], []).

group_consecutive([], _Context, Current, Acc) ->
    lists:reverse([lists:reverse(Current) | Acc]);
group_consecutive([Line | Rest], Context, [Prev | _] = Current, Acc) when
    Line - Prev =< Context * 2 + 1
->
    group_consecutive(Rest, Context, [Line | Current], Acc);
group_consecutive([Line | Rest], Context, Current, Acc) ->
    group_consecutive(Rest, Context, [Line], [lists:reverse(Current) | Acc]).
