-module(pubsub_local_sup).

-behaviour(supervisor).

%% API
-export([
  start_link/2,
  get_shards/1
]).

%% Supervisor callbacks
-export([
  init/1
]).

%%%===================================================================
%%% API functions
%%%===================================================================

-spec start_link(Scope::atom(), ShardsNum::non_neg_integer()) -> supervisor:startlink_ret().
start_link(Scope, ShardsNum) ->
  supervisor:start_link(?MODULE, {Scope, ShardsNum}).

-spec get_shards(Scope::atom()) -> {ShardsNum::non_neg_integer(), Shards::tuple()}.
get_shards(Scope) ->
  persistent_term:get({?MODULE, Scope}).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

-spec init({Scope::atom(), ShardsNum::non_neg_integer()}) ->
  {ok, {SupFlags::supervisor:sup_flags(), [ChildSpec::supervisor:child_spec()]}}.
init({Scope, ShardsNum}) ->
  SupFlags = #{strategy => one_for_one},
  {Children, Shards} =
    lists:foldl(fun(N, {Ch, Sh}) ->
                  LocalServerName = build_name(Scope, "local", N),
                  GCServerName = build_name(Scope, "gc", N),
                  Shard = {LocalServerName, GCServerName},
                  ShardSupChildren = [
                    #{id => LocalServerName,
                      start => {pubsub_local, start_link, [Shard]},
                      type => worker},
                    #{id => GCServerName,
                      start => {pubsub_gc, start_link, [Shard]},
                      type => worker}
                  ],
                  Child = #{id => N,
                            start => {pubsub_shard_sup, start_link, [ShardSupChildren]},
                            type => supervisor},
                  {[Child | Ch], setelement(N, Sh, Shard)}
                end, {[], erlang:make_tuple(ShardsNum, undefined)}, lists:seq(1, ShardsNum)),
  persistent_term:put({?MODULE, Scope}, {ShardsNum, Shards}),
  {ok, {SupFlags, Children}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

-spec build_name(Scope::atom(), WorkerType::list(), ShardNum::non_neg_integer()) -> atom().
build_name(Scope, WorkerType, ShardNum) ->
  list_to_atom(atom_to_list(Scope) ++ [$_ | WorkerType] ++ [$_ | integer_to_list(ShardNum)]).
