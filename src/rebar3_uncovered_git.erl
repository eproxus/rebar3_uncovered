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
    Re =
        ~"""
        ^                                   # line start (multiline)
        (?:
            \+\+\+\ b/(\S+)                 # new-file header, capture path
          |
            @@\ [^+]*\+(\d+)(?:,(\d+))?     # hunk header: +start[,count]
        )
        """,
    Opts = [
        multiline, extended, global, unicode, {capture, all_but_first, binary}
    ],
    case re:run(Output, Re, Opts) of
        nomatch -> #{};
        {match, Matches} -> collect_hunks(Matches, undefined, #{})
    end.

collect_hunks([], _File, Acc) ->
    Acc;
collect_hunks([[File] | Rest], _PrevFile, Acc) ->
    collect_hunks(Rest, unicode:characters_to_list(File), Acc);
collect_hunks([[<<>>, StartB] | Rest], File, Acc) ->
    add_hunk(binary_to_integer(StartB), 1, File, Acc, Rest);
collect_hunks([[<<>>, StartB, CountB] | Rest], File, Acc) ->
    add_hunk(
        binary_to_integer(StartB), binary_to_integer(CountB), File, Acc, Rest
    ).

add_hunk(S, C, File, Acc, Rest) ->
    FileLines = maps:get(File, Acc, #{}),
    NewLines = #{N => #{} || N <:- lists:seq(S, S + C - 1)},
    collect_hunks(Rest, File, Acc#{File => maps:merge(FileLines, NewLines)}).
