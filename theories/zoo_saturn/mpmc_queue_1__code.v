From zoo Require Import
  prelude.
From zoo.language Require Import
  typeclasses
  notations.
From zoo_std Require Import
  domain.
From zoo_saturn Require Import
  mpmc_queue_1__types.
From zoo Require Import
  options.

Definition mpmc_queue_1_create : val :=
  fun: <> =>
    let: "front" := ‘Node{ §Null, () } in
    { "front", "front" }.

Definition mpmc_queue_1_is_empty : val :=
  fun: "t" =>
    match: "t".{front} with
    | Node <> <> as "front_r" =>
        "front_r".{next} == §Null
    end.

Definition mpmc_queue_1_push_0 : val :=
  rec: "push" "node" "new_back" =>
    match: "node" with
    | Node <> <> as "node_r" =>
        match: "node_r".{next} with
        | Node <> <> as "next" =>
            "push" "next" "new_back"
        | Null =>
            if: ~ CAS "node_r".[next] §Null "new_back" then (
              domain_yield () ;;
              "push" "node" "new_back"
            )
        end
    end.

Definition mpmc_queue_1_fix_back : val :=
  rec: "fix_back" "t" "back" "new_back" =>
    match: "new_back" with
    | Node <> <> as "new_back_r" =>
        if:
          "new_back_r".{next} == §Null
          and
          ~ CAS "t".[back] "back" "new_back"
        then (
          domain_yield () ;;
          "fix_back" "t" "t".{back} "new_back"
        )
    end.

Definition mpmc_queue_1_push : val :=
  fun: "t" "v" =>
    match: ‘Node{ §Null, "v" } with
    | Node <> <> as "new_back" =>
        let: "back" := "t".{back} in
        mpmc_queue_1_push_0 "back" "new_back" ;;
        mpmc_queue_1_fix_back "t" "back" "new_back"
    end.

Definition mpmc_queue_1_pop : val :=
  rec: "pop" "t" =>
    match: "t".{front} with
    | Node <> <> as "front" =>
        let: "front_r" := "front" in
        match: "front_r".{next} with
        | Null =>
            §None
        | Node <> <> as "new_front" =>
            let: "new_front_r" := "new_front" in
            if: CAS "t".[front] "front" "new_front" then (
              let: "v" := "new_front_r".{data} in
              "new_front_r" <-{data} () ;;
              ‘Some( "v" )
            ) else (
              domain_yield () ;;
              "pop" "t"
            )
        end
    end.
