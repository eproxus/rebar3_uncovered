---
paths:
  - "**/*.erl"
  - "**/*.hrl"
---

# Erlang Programming Rules

* Always comment using single comment characters (%)
* Use binary sigils (`~"bin"`) over old-style binaries (`<<"bin">>`)
* Prefer map pattern matching over `maps:get` or `maps:find`:

  ```erlang
  % Don't
  Verbose = maps:get(admin, User, undefined),
  case Verbose of
      true -> delete();
      _ -> ok
  end.
  % Do
  case User of
      #{admin := true} -> delete();
      _ -> ok
  end.
  ```

* Always match patterns as early as possible to avoid `badarg` or strange
  errors:

  ```erlang
  % Don't
  switch(Opts) ->
      {List, _Length} = maps:get(items, Opts, undefined)
      handle(List).
  % Do
  switch(#{list := {List, _Length}}) -> handle(List).
  ```

* Join small functions to single line clauses:

  ```erlang
  % Don't
  check(ok) ->
      true;
  check({error, _}) ->
      false.
  % Do
  check(ok) -> true;
  check({error, _}) -> false.
  ```

* Prefer short functions with pattern matching over case statements:

  ```erlang
  % Don't
  switch(Opts) ->
      case Opts of
          #{verbose := true} -> print();
          _ -> ok
      end.
  % Do
  switch(#{verbose := true}) -> print();
  switch(_Opts) -> ok.
  ```

* Prefer list comprehensions above `lists:map/2` whenever it fits on one line.
  Use `lists:map/2` for multiline expressions.
