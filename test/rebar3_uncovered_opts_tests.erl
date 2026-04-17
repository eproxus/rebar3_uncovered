-module(rebar3_uncovered_opts_tests).

-include_lib("eunit/include/eunit.hrl").

%--- Tests ---------------------------------------------------------------------

git_disabled_default_test() ->
    ?assertMatch(#{git := false}, rebar3_uncovered:parse_opts([])).

git_scope_defaults_to_auto_test() ->
    ?assertMatch(
        #{git := auto}, rebar3_uncovered:parse_opts([{git, true}])
    ).

git_scope_staged_test() ->
    ?assertMatch(
        #{git := staged},
        rebar3_uncovered:parse_opts([{git, true}, {git_scope, "staged"}])
    ).

git_scope_unstaged_test() ->
    ?assertMatch(
        #{git := unstaged},
        rebar3_uncovered:parse_opts([{git, true}, {git_scope, "unstaged"}])
    ).

git_scope_head_test() ->
    ?assertMatch(
        #{git := {ref, "HEAD"}},
        rebar3_uncovered:parse_opts([{git, true}, {git_scope, "HEAD"}])
    ).

git_scope_origin_main_test() ->
    ?assertMatch(
        #{git := {ref, "origin/main"}},
        rebar3_uncovered:parse_opts([{git, true}, {git_scope, "origin/main"}])
    ).

git_scope_head_tilde_test() ->
    ?assertMatch(
        #{git := {ref, "HEAD~1"}},
        rebar3_uncovered:parse_opts([{git, true}, {git_scope, "HEAD~1"}])
    ).

git_scope_sha_test() ->
    ?assertMatch(
        #{git := {ref, "a1b2c3d"}},
        rebar3_uncovered:parse_opts([{git, true}, {git_scope, "a1b2c3d"}])
    ).

format_error_git_command_failed_test() ->
    Msg = iolist_to_binary(
        rebar3_uncovered:format_error({git_command_failed, 128, "oops\n"})
    ),
    ?assertEqual(<<"git exited 128:\noops\n">>, Msg).

format_error_git_not_found_test() ->
    ?assertEqual(
        "git binary not found in PATH",
        rebar3_uncovered:format_error(git_not_found)
    ).

format_error_git_timeout_test() ->
    ?assertEqual(
        "git command timed out",
        rebar3_uncovered:format_error(git_timeout)
    ).

format_error_fallback_test() ->
    %% Unknown reasons fall through to a generic ~p format
    Msg = iolist_to_binary(rebar3_uncovered:format_error(weird_reason)),
    ?assertEqual(<<"weird_reason">>, Msg).

all_keyword_removed_test() ->
    %% "all" is no longer a recognized keyword; it is now treated as a git ref
    %% (which git will likely reject at runtime). The plugin does not
    %% special-case it anymore.
    ?assertMatch(
        #{git := {ref, "all"}},
        rebar3_uncovered:parse_opts([{git, true}, {git_scope, "all"}])
    ).
