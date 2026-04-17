-module(rebar3_uncovered_git_tests).

-include_lib("eunit/include/eunit.hrl").

%--- Tests: filter_uncovered ---------------------------------------------------

%% These tests exercise the real git shell-out against the current repository.
%% They pass an empty files map so the output is deterministic regardless of
%% what the diff actually contains.

filter_uncovered_disabled_test() ->
    State = #{files => #{"src/foo.erl" => #{}}, opts => #{git => false}},
    ?assertEqual(State, rebar3_uncovered_git:filter_uncovered(State)).

filter_uncovered_auto_test() ->
    State = #{files => #{}, opts => #{git => auto}},
    ?assertMatch(
        #{files := #{}}, rebar3_uncovered_git:filter_uncovered(State)
    ).

filter_uncovered_ref_head_test() ->
    State = #{files => #{}, opts => #{git => {ref, "HEAD"}}},
    ?assertMatch(
        #{files := #{}}, rebar3_uncovered_git:filter_uncovered(State)
    ).

filter_uncovered_ref_head_tilde_test() ->
    State = #{files => #{}, opts => #{git => {ref, "HEAD~1"}}},
    ?assertMatch(
        #{files := #{}}, rebar3_uncovered_git:filter_uncovered(State)
    ).

filter_uncovered_staged_test() ->
    State = #{files => #{}, opts => #{git => staged}},
    ?assertMatch(
        #{files := #{}}, rebar3_uncovered_git:filter_uncovered(State)
    ).

filter_uncovered_unstaged_test() ->
    State = #{files => #{}, opts => #{git => unstaged}},
    ?assertMatch(
        #{files := #{}}, rebar3_uncovered_git:filter_uncovered(State)
    ).

filter_uncovered_bad_ref_test() ->
    State = #{
        files => #{}, opts => #{git => {ref, "definitely-not-a-ref-zzz-9999"}}
    },
    ?assertError(
        {git_command_failed, _, _},
        rebar3_uncovered_git:filter_uncovered(State)
    ).

%--- Tests: hide_unchanged -----------------------------------------------------

hide_unchanged_keeps_changed_test() ->
    Changed = #{5 => #{}},
    FileLines = #{5 => #{show => true, count => 0}},
    ?assertEqual(
        #{5 => #{show => true, count => 0}},
        rebar3_uncovered_git:hide_unchanged(Changed, FileLines)
    ).

hide_unchanged_strips_show_from_unchanged_test() ->
    Changed = #{5 => #{}},
    FileLines = #{10 => #{show => true, count => 0}},
    ?assertEqual(
        #{10 => #{count => 0}},
        rebar3_uncovered_git:hide_unchanged(Changed, FileLines)
    ).

hide_unchanged_leaves_no_show_untouched_test() ->
    Changed = #{},
    FileLines = #{10 => #{count => 0}},
    ?assertEqual(
        FileLines, rebar3_uncovered_git:hide_unchanged(Changed, FileLines)
    ).

%--- Tests: parse_diff ---------------------------------------------------------

empty_diff_test() ->
    ?assertEqual(#{}, rebar3_uncovered_git:parse_diff("")).

single_line_hunk_test() ->
    Diff =
        "diff --git a/src/foo.erl b/src/foo.erl\n"
        "+++ b/src/foo.erl\n"
        "@@ -0,0 +5 @@\n"
        "+new_line()\n",
    ?assertEqual(
        #{"src/foo.erl" => #{5 => #{}}}, rebar3_uncovered_git:parse_diff(Diff)
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
        #{"src/foo.erl" => #{10 => #{}, 11 => #{}, 12 => #{}}},
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
        #{"src/foo.erl" => #{1 => #{}}, "src/bar.erl" => #{5 => #{}, 6 => #{}}},
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
        #{"src/foo.erl" => #{3 => #{}, 10 => #{}, 11 => #{}}},
        rebar3_uncovered_git:parse_diff(Diff)
    ).
