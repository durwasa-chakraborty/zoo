From zoo Require Import
  prelude.
From zoo.language Require Import
  typeclasses
  notations.
From zoo Require Import
  identifier.
From zoo_std Require Import
  inf_array
  domain.
From zoo_saturn Require Import
  inf_ws_queue_1__types.
From zoo Require Import
  options.

Definition inf_ws_queue_1_create : val :=
  fun: <> =>
    { #1, #1, inf_array_create (), Proph }.

Definition inf_ws_queue_1_size : val :=
  fun: "t" =>
    "t".{back} - "t".{front}.

Definition inf_ws_queue_1_is_empty : val :=
  fun: "t" =>
    inf_ws_queue_1_size "t" == #0.

Definition inf_ws_queue_1_push : val :=
  fun: "t" "v" =>
    let: "back" := "t".{back} in
    inf_array_set "t".{data} "back" "v" ;;
    "t" <-{back} "back" + #1.

Definition inf_ws_queue_1_steal : val :=
  rec: "steal" "t" =>
    let: "id" := Id in
    let: "front" := "t".{front} in
    let: "back" := "t".{back} in
    if: "back" ≤ "front" then (
      §None
    ) else if:
       Resolve
         (CAS "t".[front] "front" ("front" + #1))
         "t".{proph}
         ("front", "id")
     then (
      ‘Some( inf_array_get "t".{data} "front" )
    ) else (
      domain_yield () ;;
      "steal" "t"
    ).

Definition inf_ws_queue_1_pop_0 : val :=
  fun: "t" "id" "back" =>
    let: "front" := "t".{front} in
    if: "back" < "front" then (
      "t" <-{back} "front" ;;
      §None
    ) else if: "front" < "back" then (
      ‘Some( inf_array_get "t".{data} "back" )
    ) else (
      let: "won" :=
        Resolve
          (CAS "t".[front] "front" ("front" + #1))
          "t".{proph}
          ("front", "id")
      in
      "t" <-{back} "front" + #1 ;;
      if: "won" then (
        ‘Some( inf_array_get "t".{data} "front" )
      ) else (
        §None
      )
    ).

Definition inf_ws_queue_1_pop : val :=
  fun: "t" =>
    let: "id" := Id in
    let: "back" := "t".{back} - #1 in
    "t" <-{back} "back" ;;
    inf_ws_queue_1_pop_0 "t" "id" "back".
