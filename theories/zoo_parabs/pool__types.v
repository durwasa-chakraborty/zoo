From zoo Require Import
  prelude.
From zoo.language Require Import
  typeclasses
  notations.
From zoo_std Require Import
  lst
  ivar_3
  array
  domain.
From zoo_parabs Require Import
  ws_hub_std.
From zoo Require Import
  options.

Notation "'context_size'" := (
  in_type "zoo_parabs.pool.context" 0
)(in custom zoo_proj
).
Notation "'context_hub'" := (
  in_type "zoo_parabs.pool.context" 1
)(in custom zoo_proj
).
Notation "'context_id'" := (
  in_type "zoo_parabs.pool.context" 2
)(in custom zoo_proj
).

Notation "'size'" := (
  in_type "zoo_parabs.pool.t" 0
)(in custom zoo_proj
).
Notation "'hub'" := (
  in_type "zoo_parabs.pool.t" 1
)(in custom zoo_proj
).
Notation "'domains'" := (
  in_type "zoo_parabs.pool.t" 2
)(in custom zoo_proj
).
