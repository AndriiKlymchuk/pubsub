-module(pubsub_sup).

-behaviour(supervisor).

%% API
-export([start_link/2]).

%% Supervisor callbacks
-export([init/1]).

%%%===================================================================
%%% API functions
%%%===================================================================

-spec start_link(Scope::atom(), ShardsNum::non_neg_integer()) -> supervisor:startlink_ret().
start_link(Scope, ShardsNum) ->
  supervisor:start_link(?MODULE, {Scope, ShardsNum}).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

-spec init({Scope::atom(), ShardsNum::non_neg_integer()}) ->
  {ok, {SupFlags::supervisor:sup_flags(), [ChildSpec::supervisor:child_spec()]}}.
init({Scope, ShardsNum}) ->
  SupFlags = #{strategy => rest_for_one},
  Children = [
    #{id => pubsub_local_sup,
      start => {pubsub_local_sup, start_link, [Scope, ShardsNum]},
      type => supervisor},
    #{id => pubsub_pg2_server,
      start => {pubsub_pg2_server, start_link, [Scope]},
      type => worker}
  ],
  {ok, {SupFlags, Children}}.
