begin;

set search_path = cardio;

truncate card cascade;
truncate layer cascade;

insert into message
(type, topics, aggregate_id, payload) select
'card_created', array['card', 'board', 'test1'], uuid4(), json_build_object(
    'title', 'root card ' || i,
    'description', random()::text
)
from generate_series(1, 30) i;

insert into message
(type, topics, aggregate_id, payload) select
'card_created', array['card', 'board', 'test1'], uuid4(), json_build_object(
    'title', 'sub card 1' || i,
    'description', random()::text
)
from generate_series(1, 30) i;

with root_layer as (
    insert into layer
    (name, description) select
    'root layer ' || i, random()
    from generate_series(1, 3) i
    returning layer_id, name
)
, sub1_layer as (
    insert into layer
    (name, description, parent_id) select
    concat_ws(' > ', 'sub1 layer ' || i, root_layer.name), random(), root_layer.layer_id
    from generate_series(1, 5) i, root_layer
    returning layer_id, name
)
, sub2_layer as (
    insert into layer
    (name, description, parent_id) select
    concat_ws(' > ', 'sub2 layer ' || i, sub1_layer.name), random(), sub1_layer.layer_id
    from generate_series(1, 6) i, sub1_layer
    returning layer_id, name
)
, root_card as (
    insert into card
    (name, description) select
    'root card ' || i, random()
    from generate_series(1, 100) i
    returning card_id, name
)
, sub1_card as (
    insert into card
    (name, description, parent_id) select
    concat_ws(' > ', 'sub1 card ' || i, root_card.name), random(), root_card.card_id
    from generate_series(1, 20) i, root_card
    returning card_id, name
)
, sub2_card as (
    insert into card
    (name, description, parent_id) select
    concat_ws(' > ', 'sub2 card ' || i, sub1_card.name), random(), sub1_card.card_id
    from generate_series(1, 10) i, sub1_card
    returning card_id, name
)
, board as (
    insert into card_in_layer
    (card_id, layer_id) select
    any_card.card_id,
    any_layer.layer_id
    from
        (table root_card union all table sub1_card union all table sub2_card) any_card,
        (table root_layer union all table sub1_layer union all table sub2_layer) any_layer
    returning *
)
select count(*) from board;

commit;
