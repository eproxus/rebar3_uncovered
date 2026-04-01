-module(rebar3_uncovered_git_tests).

-include_lib("eunit/include/eunit.hrl").

%--- Tests ---------------------------------------------------------------------

empty_diff_test() ->
    ?assertEqual(#{}, rebar3_uncovered_git:parse_diff("")).

single_line_hunk_test() ->
    Diff =
        "diff --git a/src/foo.erl b/src/foo.erl\n"
        "+++ b/src/foo.erl\n"
        "@@ -0,0 +5 @@\n"
        "+new_line()\n",
    ?assertEqual(
        #{"src/foo.erl" => [5]}, rebar3_uncovered_git:parse_diff(Diff)
    ).

multi_line_hunk_test() ->
    Diff =
        "diff --git a/src/foo.erl b/src/foo.erl\n"
        "+++ b/src/foo.erl\n"
        "@@ -10,0 +10,3 @@\n"
        "+line1\n"
        "+line2\n"
        "+line3\n",
    ?assertEqual(
        #{"src/foo.erl" => [10, 11, 12]},
        rebar3_uncovered_git:parse_diff(Diff)
    ).

multiple_files_test() ->
    Diff =
        "diff --git a/src/foo.erl b/src/foo.erl\n"
        "+++ b/src/foo.erl\n"
        "@@ -0,0 +1 @@\n"
        "+line1\n"
        "diff --git a/src/bar.erl b/src/bar.erl\n"
        "+++ b/src/bar.erl\n"
        "@@ -0,0 +5,2 @@\n"
        "+line1\n"
        "+line2\n",
    ?assertEqual(
        #{"src/foo.erl" => [1], "src/bar.erl" => [5, 6]},
        rebar3_uncovered_git:parse_diff(Diff)
    ).

multiple_hunks_same_file_test() ->
    Diff =
        "diff --git a/src/foo.erl b/src/foo.erl\n"
        "+++ b/src/foo.erl\n"
        "@@ -0,0 +3 @@\n"
        "+line1\n"
        "@@ -0,0 +10,2 @@\n"
        "+line2\n"
        "+line3\n",
    ?assertEqual(
        #{"src/foo.erl" => [3, 10, 11]},
        rebar3_uncovered_git:parse_diff(Diff)
    ).
