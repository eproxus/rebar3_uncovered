-module(rebar3_uncovered_git).

% API
-export([changed_lines/1]).

%--- API -----------------------------------------------------------------------

-spec changed_lines(Mode) -> #{file:filename() => [pos_integer()]} when
    Mode :: all | staged | unstaged.
changed_lines(_Mode) ->
    #{}.
