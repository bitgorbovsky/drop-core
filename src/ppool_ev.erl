-module(ppool_ev).
-behaviour(gen_event).


%% API.
-export([start_link/1
        
        ]).

%% gen_event.
-export([init/1, 
         handle_event/2, 
         handle_call/2,
         handle_info/2, 
         code_change/3,
         terminate/2
        ]).
 
-include("ppool.hrl").

-record(state, {
          pid,
          filter,
          api
}).


start_link(Name) ->

    EvName=list_to_atom(atom_to_list(Name)++"_ev"),
	{ok,Pid}=gen_event:start_link({local, EvName}),

     pg2:create(EvName),
      pg2:join(EvName, Pid),

     {ok,Pid}.


init([Pid, Filter, API]) ->

	{ok, #state{pid=Pid, filter=Filter, api=API}}.


%% all

handle_event({msg, {_,R,[Msg]}=_M}, 
             #state{pid=Pid, filter=Filter, api=API}=State)
      when Filter=/=<<"no">>, API=:=all ->

    ?Debug({event_all, self(), Pid, Msg, Filter, API}),

     case binary:match(Msg, Filter) of
         nomatch -> ok;
               _ -> ppool_worker:cast_all_workers(Pid,
                                R, <<Msg/binary, <<"\n">>/binary>>)
     end,
    
      {ok, State};


handle_event({msg, {_,R,[Msg]}=_M}, 
             #state{pid=Pid, api=API}=State)
      when API=:=all ->

    ?Debug({event_all, self(), Pid, Msg, API}),
      ppool_worker:cast_all_workers(Pid,
                                R, <<Msg/binary, <<"\n">>/binary>>),
 
      {ok, State};


%% one

handle_event({msg, {_,R,[Msg]}=_M}, 
             #state{pid=Pid, filter=Filter, api=API}=State)
      when Filter=/=<<"no">>, API=:=one ->

    ?Debug({event_one, self(), Pid, Msg, Filter, API}),

     case binary:match(Msg, Filter) of
         nomatch -> ok;
               _ -> call_worker0(Pid, R, <<Msg/binary, <<"\n">>/binary>>)
     end,
 
      {ok, State};


handle_event({msg, {_,R,[Msg]}=_M}, 
             #state{pid=Pid, api=API}=State)
      when API=:=one ->

     ?Debug({event_one, self(), Pid, Msg, API}),

        call_worker0(Pid, R, <<Msg/binary, <<"\n">>/binary>>),
                     
    
      {ok, State};


%% sone

handle_event({msg, {_,R,[Msg]}=_M}, 
             #state{pid=Pid, filter=Filter, api=API}=State)
      when Filter=/=<<"no">>, API=:=sone ->

    ?Debug({event_one, self(), Pid, Msg, Filter, API}),

     case binary:match(Msg, Filter) of
         nomatch -> ok;
               _ -> ppool_worker:cast_worker(Pid,
                                 R, <<Msg/binary, <<"\n">>/binary>>)
 
     end,
 
      {ok, State};


handle_event({msg, {_,R,[Msg]}=_M}, 
             #state{pid=Pid, api=API}=State)
      when API=:=sone ->

     ?Debug({event_one, self(), Pid, Msg, API}),

        ppool_worker:cast_worker(Pid, R, <<Msg/binary, <<"\n">>/binary>>),
    
      {ok, State};




%% done

handle_event({msg, {_,R,[Msg]}=_M}, 
             #state{pid=Pid, filter=Filter, api=API}=State)
      when Filter=/=<<"no">>, API=:=done ->

    ?Debug({event_one, self(), Pid, Msg, Filter, API}),

     case binary:match(Msg, Filter) of
         nomatch -> ok;
               _ -> call_worker(Pid, R, <<Msg/binary, <<"\n">>/binary>>)
     end,
 
      {ok, State};


handle_event({msg, {_,R,[Msg]}=_M}, 
             #state{pid=Pid, api=API}=State)
      when API=:=done ->

     ?Debug({event_one, self(), Pid, Msg, API}),

         call_worker(Pid, R, <<Msg/binary, <<"\n">>/binary>>),
    
      {ok, State};


%% dall

handle_event({msg, {_,R,[Msg]}=_M}, 
             #state{pid=Pid, filter=Filter, api=API}=State)
      when Filter=/=<<"no">>, API=:=dall ->

    ?Debug({event_dall, self(), Pid, Msg, Filter, API}),

     case binary:match(Msg, Filter) of
         nomatch -> ok;
               _ -> ppool_worker:dacast_worker(Pid, 
                            R, <<Msg/binary, <<"\n">>/binary>>) 
     end,
 
      {ok, State};


handle_event({msg, {_,R,[Msg]}=_M}, 
             #state{pid=Pid, api=API}=State)
      when API=:=dall ->

     ?Debug({event_dall, self(), Pid, Msg, API}),

        ppool_worker:dacast_worker(Pid, R, <<Msg/binary, <<"\n">>/binary>>),
    
      {ok, State};



handle_event(Event, State) ->
     error_logger:info_msg({no_match_type,Event}),
      {ok, State}.
 

handle_call(_, State) ->
    {ok, ok, State}.
 

handle_info(_, State) ->
    {ok, State}.
 
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
 
terminate(_Reason, _State) ->
    ok.



call_worker0(Pid, R, Msg) ->

         case ppool_worker:call_cast_worker(Pid, R, Msg) of
             {ok, []} -> 
               %%  error_logger:warning_msg("no more subscribers ~p, ~p~n",
               %%                                           [{Pid,R}, Msg]),

                %% notify system 
                 ppool_worker:add_nomore_info(Pid),
                %%%%%%

                  ppool_worker:cast_worker(Pid, R, Msg);

             {ok, _Res} -> ok

         end.


call_worker(Pid, R, Msg) ->

         case ppool_worker:call_cast_worker(Pid, R, Msg) of
             {ok, []} -> 
               %% error_logger:warning_msg("no more subscribers ~p, ~p~n",
               %%                                          [{Pid,R}, Msg]),

                %% notify system 
                 ppool_worker:add_nomore_info(Pid),
                %%%%%%

                  ppool_worker:dcast_worker(Pid, R, Msg);

             {ok, _Res} -> ok

         end.

