-module(pubsub_pg2_server).

-behaviour(gen_server).

%% API
-export([
  start_link/1,
  broadcast/4
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

-record(state, {scope :: atom()}).

%%%===================================================================
%%% API
%%%===================================================================

-spec start_link(Scope::atom()) -> gen:start_ret().
start_link(Scope) ->
  gen_server:start_link(?MODULE, Scope, []).

-spec broadcast(Msg::term(), Scope::atom(), Topic::pubsub:topic(), Exclude::pid() | undefined) ->
  ok | {error, no_such_group}.
broadcast(Msg, Scope, Topic, Exclude) ->
  case pg2:get_members(pg2_namespace(Scope)) of
    {error, {no_such_group, _}} -> {error, no_such_group};
    Pids ->
      Node = node(),
      lists:foreach(fun(Pid) when node(Pid) =:= Node ->
                      pubsub_local:broadcast(Msg, Scope, Topic, Exclude);
                       (Pid) ->
                      Pid ! {forward_to_local, Msg, Topic, Exclude}
                    end, Pids)
  end.

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init(Scope) ->
  PG2Namespace = pg2_namespace(Scope),
  ok = pg2:create(PG2Namespace),
  ok = pg2:join(PG2Namespace, self()),
  {ok, #state{scope = Scope}}.

handle_call(_Request, _From, State) ->
  {reply, ok, State}.

handle_cast(_Request, State) ->
  {noreply, State}.

handle_info({forward_to_local, Msg, Topic, Exclude},
            #state{scope = Scope} = State) ->
  pubsub_local:broadcast(Msg, Scope, Topic, Exclude),
  {noreply, State};
handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%% ===================================================================
%% Internal functions
%% ===================================================================

pg2_namespace(Scope) -> {?MODULE, Scope}.
