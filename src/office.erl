%%%-------------------------------------------------------------------
%%% @author Joe
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 02. May 2016 6:29 PM
%%%-------------------------------------------------------------------
-module(office).
-author("Joe").
-export([room/4, student/2, officedemo/0, next/1, index_of/2]).

next([_|T]) -> T.
index_of(Name, Queue) -> index_of(Name, Queue, 1).
index_of(_, [], _) -> 0;
index_of(Name, [Name|_], Index) -> Index;
index_of(Name, [_|T], Index) -> index_of(Name, T, Index +1).
room(Students, Capacity, Queue, Helping) ->
  receive
    {From,Name, help}->
      if
        Helping ->
          From ! {self(), busy},
          room(Students, Capacity, Queue, Helping);
        true ->
          From ! {self(), not_busy},
          room(Students, Capacity, Queue, true)
      end;
    {From, enter, Name} when length(Queue) =:= 0, Capacity > 0 ->
      From ! {self(), ok},
      room([Name|Students], Capacity-1, Queue, Helping);
  % student entering, not at capacity
    {From, enter, Name} when Capacity > 0 ->
      case Name =:= hd(Queue) of
        true ->
          From ! {self(), ok},
          room([Name|Students], Capacity - 1, next(Queue), Helping);
        false ->
          From ! {self(), in_line, rand:uniform(1000), Queue},
          room(Students, Capacity, Queue, Helping)
      end;
  % student entering, at capacity
    {From, enter, Name} ->
      Contains = string:str(Queue, [Name]),
      if
        Contains =:= 0 ->
          Index = length(Queue),
          Sleeptime = 1000 * Index,
          From ! {self(), room_full, Sleeptime},
          room(Students, Capacity, Queue ++ [Name], Helping);

        true ->
          Sleeptime = 1000 * Contains,
          From ! {self(), room_full, Sleeptime},
          room(Students, Capacity, Queue, Helping)
      end;


  % student leaving
    {From, leave, Name, thanks} ->
      % make sure they are already in the room
      case lists:member(Name, Students) of
        true ->
          From ! {self(), ok},
          room(lists:delete(Name, Students), Capacity + 1, Queue, false);
        false ->
          From ! {self(), not_found},
          room(Students, Capacity, Queue, Helping)
      end
  end.

ask_help(Office, Name) ->
  Office ! {self(),Name, help},
  receive
    {_, busy} ->
      io:format("Student ~s wanted help but the office told him to wait for 2 seconds ~n", [Name]),
      timer:sleep(2000),
      ask_help(Office, Name);
    {_, not_busy} ->
      studentWork(Name)
  end.

studentWork(Name) ->
  SleepTime = rand:uniform(7000) + 3000,
  io:format("~s Got help and will work for ~B ms.~n", [Name, SleepTime]),
  timer:sleep(SleepTime).

student(Office, Name) ->
  timer:sleep(rand:uniform(3000)),
  Office ! {self(), enter, Name},
  receive
  % Success; can enter room.
    {_, ok} ->
      io:format("~s entered room ~n", [Name]),
      ask_help(Office, Name),
      Office ! {self(), leave, Name, thanks},
      io:format("~s left the Office.~n", [Name]);

  % Office is full; sleep and try again.
    {_, room_full, SleepTime} ->
      io:format("~s could not enter and must wait ~B ms.~n", [Name, SleepTime]),
      timer:sleep(SleepTime),
      student(Office, Name);
    {_, in_line, SleepTime} ->
      io:format("~s is already in line~n", [Name]),
      timer:sleep(SleepTime),
      student(Office, Name)
  end.

officedemo() ->
  R = spawn(office, room, [[], 3, [], false]), % start the room process with an empty list of students
  spawn(office, student, [R, "Ada"]),
  spawn(office, student, [R, "Barbara"]),
  spawn(office, student, [R, "Charlie"]),
  spawn(office, student, [R, "Donald"]),
  spawn(office, student, [R, "Elaine"]),
  spawn(office, student, [R, "Frank"]),
  spawn(office, student, [R, "George"]).