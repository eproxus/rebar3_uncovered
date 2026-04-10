-module(rebar3_uncovered_git).

% API
-export([filter_uncovered/2]).

-ifdef(TEST).
-export([parse_diff/1]).
-ignore_xref(parse_diff/1).
-endif.

%--- API -----------------------------------------------------------------------

filter_uncovered(Uncovered, #{git := false}) ->
    Uncovered;
filter_uncovered(Uncovered, #{git := Mode}) ->
    Changed = changed_lines(Mode),
    [
        Line
     || #{file := File, line := LineNo} = Line <:- Uncovered,
        lists:member(LineNo, maps:get(File, Changed, []))
    ].

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
parse_lines(["@@ " ++ _ = Line | Rest], File, Acc) when
    File =/= undefined
->
    LineNos = parse_hunk(Line),
    Existing = maps:get(File, Acc, []),
    parse_lines(Rest, File, Acc#{File => Existing ++ LineNos});
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
