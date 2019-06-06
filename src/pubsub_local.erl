-module(pubsub_local).

-behaviour(gen_server).

%% API
-export([
  start_link/1,
  subscribe/3,
  unsubscribe/3,
  broadcast/4,
  subscribers/2,
  subscriptions/2
]).

%% gen_server callbacks
-export([
  init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3
]).

%%%===================================================================
%%% API
%%%===================================================================

-spec start_link(pubsub:shard()) -> gen:start_ret().
start_link({LocalServerName, _} = ShardServers) ->
  gen_server:start_link({local, LocalServerName}, ?MODULE, ShardServers, []).

-spec subscribe(Pid::pid(), Scope::atom(), Topic::pubsub:topic()) -> ok.
subscribe(Pid, Scope, Topic) ->
  {Local, Gc} = shard_for_pid(Scope, Pid),
  ok = gen_server:call(Local, {link, Pid}),
  true = ets:insert(Local, {Topic, Pid}),
  true = ets:insert(Gc, {Pid, Topic}),
  ok.

-spec unsubscribe(Pid::pid(), Scope::atom(), Topic::pubsub:topic()) -> ok.
unsubscribe(Pid, Scope, Topic) ->
  {Local, Gc} = shard_for_pid(Scope, Pid),
  true = ets:match_delete(Gc, {Pid, Topic}),
  true = ets:match_delete(Local, {Topic, Pid}),
  case ets:select_count(Gc, [{{Pid, '_'}, [], [true]}]) of
    0 -> gen_server:call(Local, {unlink, Pid});
    _ -> ok
  end.

-spec broadcast(Msg::term(), Scope::atom(), Topic::pubsub:topic(), Exclude::pid() | undefined) -> ok.
broadcast(Msg, Scope, Topic, Exclude) ->
  {ShardsNum, Shards} = pubsub_local_sup:get_shards(Scope),
  lists:foreach(fun(N) ->
                  do_broadcast(Msg, Topic, Exclude, element(N, Shards))
                end, lists:seq(1, ShardsNum)).

-spec subscribers(Scope::atom(), Topic::pubsub:topic()) -> [pid()].
subscribers(Scope, Topic) ->
  {ShardsNum, Shards} = pubsub_local_sup:get_shards(Scope),
  lists:foldl(fun(N, Acc) ->
                Acc ++ subscribers_by_shard(Topic, element(N, Shards))
              end, [], lists:seq(1, ShardsNum)).

-spec subscriptions(Pid::pid(), Scope::atom()) -> [pubsub:topic()].
subscriptions(Pid, Scope) ->
  {_, Gc} = shard_for_pid(Scope, Pid),
  ets:lookup_element(Gc, Pid, 2).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init({LocalServerName, GCServerName}) ->
  Opts = [bag, named_table, public, {read_concurrency, true}, {write_concurrency, true}],
  ets:new(LocalServerName, Opts), % Topics table
  ets:new(GCServerName, Opts),    % Pids table
  process_flag(trap_exit, true),
  {ok, #{gc => GCServerName}}.

handle_call({link, Pid}, _From, State) ->
  link(Pid),
  {reply, ok, State};
handle_call({unlink, Pid}, _From, State) ->
  unlink(Pid),
  {reply, ok, State};
handle_call(_Request, _From, State) ->
  {reply, ok, State}.

handle_cast(_Request, State) ->
  {noreply, State}.

handle_info({'EXIT', Pid, _}, #{gc := GCServer} = State) ->
  pubsub_gc:down(GCServer, Pid),
  {noreply, State};
handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

-spec shard_for_pid(Scope::atom(), Pid::pid()) -> pubsub:shard().
shard_for_pid(Scope, Pid) ->
  {ShardsNum, Shards} = pubsub_local_sup:get_shards(Scope),
  element(erlang:phash2(Pid, ShardsNum) + 1, Shards).

-spec do_broadcast(Msg::term(), Topic::pubsub:topic(),
                   Exclude::pid() | undefined, Shard::pubsub:shard()) ->
  ok.
do_broadcast(Msg, Topic, Exclude, Shard) ->
  lists:foreach(fun(Pid) when Pid =:= Exclude -> ok;
                   (Pid) -> Pid ! Msg
                end, subscribers_by_shard(Topic, Shard)).

-spec subscribers_by_shard(pubsub:topic(), pubsub:shard()) -> [pid()].
subscribers_by_shard(Topic, {Local, _}) ->
  try
    ets:lookup_element(Local, Topic, 2)
  catch
    error:badarg -> []
  end.
