-module(rebar3_uncovered_git).

% API
-export([filter_uncovered/1]).

-ifdef(TEST).
-export([parse_diff/1]).
-ignore_xref(parse_diff/1).
-endif.

%--- API -----------------------------------------------------------------------

filter_uncovered(#{opts := #{git := false}} = S) ->
    S;
filter_uncovered(#{files := Files, opts := #{git := Mode}} = S) ->
    Changed = changed_lines(Mode),
    S#{
        files := maps:intersect_with(
            fun(_, ChangedLines, FileLines) ->
                hide_unchanged(ChangedLines, FileLines)
            end,
            Changed,
            Files
        )
    }.

hide_unchanged(ChangedLines, FileLines) ->
    maps:map(
        fun
            (LineNo, #{show := true} = Val) when
                not is_map_key(LineNo, ChangedLines)
            ->
                maps:remove(show, Val);
            (_, Val) ->
                Val
        end,
        FileLines
    ).

%--- Internal ------------------------------------------------------------------

changed_lines(Mode) ->
    Output = git_diff(Mode),
    parse_diff(Output).

git_diff(all) -> os:cmd("git diff -U0 --no-color --no-ext-diff HEAD");
git_diff(staged) -> os:cmd("git diff -U0 --no-color --no-ext-diff --cached");
git_diff(unstaged) -> os:cmd("git diff -U0 --no-color --no-ext-diff").

parse_diff(Output) ->
    Lines = string:split(Output, "\n", all),
    parse_lines(Lines, undefined, #{}).

parse_lines([], _File, Acc) ->
    Acc;
parse_lines(["+++ b/" ++ Path | Rest], _File, Acc) ->
    parse_lines(Rest, Path, Acc);
parse_lines(["@@ " ++ _ = Line | Rest], File, Acc) when File =/= undefined ->
    FileLines = maps:get(File, Acc, #{}),
    NewLines = #{N => #{} || N <:- parse_hunk(Line)},
    parse_lines(Rest, File, Acc#{File => maps:merge(FileLines, NewLines)});
parse_lines([_ | Rest], File, Acc) ->
    parse_lines(Rest, File, Acc).

parse_hunk(Line) ->
    case
        re:run(Line, "\\+(\\d+)(?:,(\\d+))?", [{capture, all_but_first, list}])
    of
        {match, [Start, Count]} ->
            S = list_to_integer(Start),
            C = list_to_integer(Count),
            lists:seq(S, S + C - 1);
        {match, [Start]} ->
            [list_to_integer(Start)]
    end.
