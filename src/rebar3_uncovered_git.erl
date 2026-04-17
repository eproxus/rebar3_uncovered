-module(rebar3_uncovered_git).

% API
-export([filter_uncovered/1]).

-ifdef(TEST).
-export([parse_diff/1, hide_unchanged/2]).
-ignore_xref(parse_diff/1).
-ignore_xref(hide_unchanged/2).
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

changed_lines(staged) ->
    parse_diff(git(["diff", "-U0", "--no-color", "--no-ext-diff", "--cached"]));
changed_lines(unstaged) ->
    parse_diff(git(["diff", "-U0", "--no-color", "--no-ext-diff"]));
changed_lines(auto) ->
    changed_lines({ref, auto_ref()});
changed_lines({ref, Ref}) ->
    MergeBase = string:trim(git(["merge-base", Ref, "HEAD"])),
    parse_diff(git(["diff", "-U0", "--no-color", "--no-ext-diff", MergeBase])).

auto_ref() ->
    first_resolvable(["origin/HEAD", "origin/main", "origin/master", "HEAD"]).

first_resolvable([Ref]) ->
    Ref;
first_resolvable([Ref | Rest]) ->
    try
        _ = git(["rev-parse", "--verify", "--quiet", Ref]),
        Ref
    catch
        error:{git_command_failed, _, _} -> first_resolvable(Rest)
    end.

git(Args) ->
    case os:find_executable("git") of
        false -> error(git_not_found);
        Path -> run_git(Path, Args)
    end.

run_git(Path, Args) ->
    Port = erlang:open_port(
        {spawn_executable, Path},
        [{args, Args}, exit_status, binary, stderr_to_stdout]
    ),
    collect(Port, <<>>).

collect(Port, Acc) ->
    receive
        {Port, {data, Data}} ->
            collect(Port, <<Acc/binary, Data/binary>>);
        {Port, {exit_status, 0}} ->
            unicode:characters_to_list(Acc);
        {Port, {exit_status, N}} ->
            error({git_command_failed, N, unicode:characters_to_list(Acc)})
    after 300000 ->
        try
            port_close(Port)
        catch
            _:_ -> ok
        after
            error(git_timeout)
        end
    end.

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
