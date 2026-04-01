-module(rebar3_uncovered_git).

% API
-export([changed_lines/1]).

%--- API -----------------------------------------------------------------------

-spec changed_lines(all) -> #{file:filename() => [pos_integer()]}.
changed_lines(Mode) ->
    Root = repo_root(),
    Output = git_diff(Mode),
    parse_diff(Output, Root).

%--- Internal ------------------------------------------------------------------

-spec repo_root() -> file:filename().
repo_root() ->
    string:trim(os:cmd("git rev-parse --show-toplevel"), both).

-spec git_diff(all) -> string().
git_diff(all) -> os:cmd("git diff -U0 --no-color --no-ext-diff HEAD").

-spec parse_diff(string(), file:filename()) ->
    #{file:filename() => [pos_integer()]}.
parse_diff(Output, Root) ->
    Lines = string:split(Output, "\n", all),
    parse_lines(Lines, Root, undefined, #{}).

-spec parse_lines(
    [string()],
    file:filename(),
    file:filename() | undefined,
    #{file:filename() => [pos_integer()]}
) ->
    #{file:filename() => [pos_integer()]}.
parse_lines([], _Root, _File, Acc) ->
    Acc;
parse_lines(["+++ b/" ++ Path | Rest], Root, _File, Acc) ->
    parse_lines(Rest, Root, filename:join(Root, Path), Acc);
parse_lines(["@@ " ++ _ = Line | Rest], Root, File, Acc) when
    File =/= undefined
->
    LineNos = parse_hunk(Line),
    Existing = maps:get(File, Acc, []),
    parse_lines(Rest, Root, File, Acc#{File => Existing ++ LineNos});
parse_lines([_ | Rest], Root, File, Acc) ->
    parse_lines(Rest, Root, File, Acc).

-spec parse_hunk(string()) -> [pos_integer()].
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
