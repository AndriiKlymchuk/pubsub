-module(pubsub_shard_sup).

-behaviour(supervisor).

%% API
-export([start_link/1]).

%% Supervisor callbacks
-export([init/1]).

%%%===================================================================
%%% API functions
%%%===================================================================

-spec(start_link(ShardChildren::[supervisor:child_spec()]) ->
  {ok, Pid::pid()} | ignore | {error, Reason::term()}).
start_link(ShardChildren) ->
  supervisor:start_link(?MODULE, ShardChildren).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

-spec init(ShardChildren::[supervisor:child_spec()]) ->
  {ok, {SupFlags::supervisor:sup_flags(), [ChildSpec::supervisor:child_spec()]}}.
init(ShardChildren) ->
  {ok, {#{strategy => one_for_all}, ShardChildren}}.
