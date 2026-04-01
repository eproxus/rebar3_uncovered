-module(rebar3_uncovered_source).

-export_type([uncovered_region/0]).

-type uncovered_region() :: #{
    file := file:filename(),
    lines := [{pos_integer(), binary(), covered | uncovered}]
}.

% API
-export([resolve_files/2, read_regions/2]).

%--- API -----------------------------------------------------------------------

resolve_files(UncoveredLines, Apps) ->
    SourceDirs = [
        % elp:ignore W0017
        filename:join(rebar_app_info:dir(App), "src")
     || App <:- Apps
    ],
    {ok, Cwd} = file:get_cwd(),
    lists:filtermap(
        fun(#{module := Mod, line := Line}) ->
            case find_source(Mod, SourceDirs) of
                {ok, AbsFile} ->
                    File = make_relative(AbsFile, Cwd),
                    {true, #{module => Mod, file => File, line => Line}};
                error ->
                    false
            end
        end,
        UncoveredLines
    ).

read_regions(UncoveredLines, Context) ->
    Grouped = group_by_file(UncoveredLines),
    lists:flatmap(
        fun({File, Lines}) -> file_regions(File, Lines, Context) end,
        maps:to_list(Grouped)
    ).

%--- Internal ------------------------------------------------------------------

group_by_file(Lines) ->
    lists:foldl(
        fun(#{file := File, line := Line}, Acc) ->
            maps:update_with(File, fun(Ls) -> [Line | Ls] end, [Line], Acc)
        end,
        #{},
        Lines
    ).

file_regions(File, UncoveredLines, Context) ->
    case file:read_file(File) of
        {ok, Content} ->
            AllLines = binary:split(Content, ~"\n", [global]),
            Sorted = lists:usort(UncoveredLines),
            Groups = group_consecutive(Sorted, Context),
            [build_region(File, Group, AllLines, Context) || Group <:- Groups];
        {error, _} ->
            []
    end.

group_consecutive([], _Context) ->
    [];
group_consecutive([First | Rest], Context) ->
    group_consecutive(Rest, Context, [First], []).

group_consecutive([], _Context, Current, Acc) ->
    lists:reverse([lists:reverse(Current) | Acc]);
group_consecutive([Line | Rest], Context, [Prev | _] = Current, Acc) when
    Line - Prev =< Context * 2
->
    group_consecutive(Rest, Context, [Line | Current], Acc);
group_consecutive([Line | Rest], Context, Current, Acc) ->
    group_consecutive(Rest, Context, [Line], [lists:reverse(Current) | Acc]).

build_region(File, UncoveredLines, AllLines, Context) ->
    First = max(1, hd(UncoveredLines) - Context),
    Last = min(length(AllLines), lists:last(UncoveredLines) + Context),
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

find_source(Mod, SourceDirs) ->
    Filename = atom_to_list(Mod) ++ ".erl",
    Paths = [
        Path
     || Dir <:- SourceDirs,
        Path <:- [filename:join(Dir, Filename)],
        filelib:is_file(Path)
    ],
    find_source_result(Paths).

find_source_result([File | _]) -> {ok, File};
find_source_result([]) -> error.

make_relative(Path, Base) ->
    Prefix = Base ++ "/",
    case lists:prefix(Prefix, Path) of
        true -> lists:nthtail(length(Prefix), Path);
        false -> Path
    end.
