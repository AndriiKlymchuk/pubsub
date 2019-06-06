-module(pubsub_gc).

-behaviour(gen_server).

%% API
-export([
  start_link/1,
  down/2
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
start_link({_, GCServerName} = Shard) ->
  gen_server:start_link({local, GCServerName}, ?MODULE, Shard, []).

-spec down(atom(), pid()) -> ok.
down(GCServer, Pid) ->
  gen_server:cast(GCServer, {down, Pid}).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init({LocalServerName, GCServerName}) ->
  {ok, #{topics => LocalServerName, pids => GCServerName}}.

handle_call(_Request, _From, State) ->
  {reply, ok, State}.

handle_cast({down, Pid}, #{pids := Pids, topics := Topics} = State) ->
  try
    Topics0 = ets:lookup_element(Pids, Pid, 2),
    lists:foreach(fun(Topic) ->
                    true = ets:match_delete(Topics, {Topic, {Pid, '_'}})
                  end, Topics0),
    true = ets:match_delete(Pids, {Pid, '_'})
  catch
    error:badarg -> badarg
  end,
  {noreply, State};
handle_cast(_Request, State) ->
  {noreply, State}.

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.
