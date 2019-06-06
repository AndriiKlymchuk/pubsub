-module(pubsub).

%% API
-export([
  subscribe/2, subscribe/3,
  unsubscribe/2, unsubscribe/3,
  publish/3, publish/4
]).

-type shard() :: {LocalServerName::atom(), GcServerName::atom()}.
-type topic() :: binary().

-export_type([shard/0, topic/0]).

%%%===================================================================
%%% API
%%%===================================================================

-spec subscribe(Scope::atom(), Topic::topic()) -> ok.
subscribe(Scope, Topic) ->
  subscribe(self(), Scope, Topic).

-spec subscribe(Pid::pid(), Scope::atom(), Topic::topic()) -> ok.
subscribe(Pid, Scope, Topic) ->
  pubsub_local:subscribe(Pid, Scope, Topic).

-spec unsubscribe(Scope::atom(), Topic::topic()) -> ok.
unsubscribe(Scope, Topic) ->
  unsubscribe(self(), Scope, Topic).

-spec unsubscribe(Pid::pid(), Scope::atom(), Topic::topic()) -> ok.
unsubscribe(Pid, Scope, Topic) ->
  pubsub_local:unsubscribe(Pid, Scope, Topic).

-spec publish(Msg::term(), Scope::atom(), Topic::topic()) ->
  ok | {error, term()}.
publish(Msg, Scope, Topic) ->
  publish(Msg, Scope, Topic, undefined).

-spec publish(Msg::term(), Scope::atom(), Topic::topic(), Exclude::pid() | undefined) ->
  ok | {error, term()}.
publish(Msg, Scope, Topic, Exclude) ->
  pubsub_pg2_server:broadcast(Msg, Scope, Topic, Exclude).
