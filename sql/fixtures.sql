begin;

set search_path = cardio;

truncate card cascade;
truncate layer cascade;

with root_layer as (
    insert into message
    (type, topics, aggregate_id, payload) select
    'layer_created', array['layer', 'board'], uuid4(), json_build_object(
        'title', 'root layer ' || i,
        'description', random()::text
    )
    from generate_series(1, 3) i
    returning aggregate_id as layer_id, payload->>'title' as title
)
, sub1_layer as (
    insert into message
    (type, topics, aggregate_id, payload) select
    'layer_created', array['layer', 'board'], uuid4(), json_build_object(
        'title', concat_ws(' > ', 'sub1 layer ' || i, parent.title),
        'description', random()::text,
        'parent_id', parent.layer_id
    )
    from generate_series(1, 5) i, root_layer as parent
    returning aggregate_id as layer_id, payload->>'title' as title
)
, sub2_layer as (
    insert into message
    (type, topics, aggregate_id, payload) select
    'layer_created', array['layer', 'board'], uuid4(), json_build_object(
        'title', concat_ws(' > ', 'sub2 layer ' || i, parent.title),
        'description', random()::text,
        'parent_id', parent.layer_id
    )
    from generate_series(1, 6) i, sub1_layer as parent
    returning aggregate_id as layer_id, payload->>'title' as title
)
, root_card as (
    insert into message
    (type, topics, aggregate_id, payload) select
    'card_created', array['card', 'board'], uuid4(), json_build_object(
        'title', 'root card ' || i,
        'description', random()::text
    )
    from generate_series(1, 3) i
    returning aggregate_id as card_id, payload->>'title' as title
)
, sub1_card as (
    insert into message
    (type, topics, aggregate_id, payload) select
    'card_created', array['card', 'board'], uuid4(), json_build_object(
        'title', concat_ws(' > ', 'sub1 card ' || i, parent.title),
        'description', random()::text,
        'parent_id', parent.card_id
    )
    from generate_series(1, 5) i, root_card as parent
    returning aggregate_id as card_id, payload->>'title' as title
)
, sub2_card as (
    insert into message
    (type, topics, aggregate_id, payload) select
    'card_created', array['card', 'board'], uuid4(), json_build_object(
        'title', concat_ws(' > ', 'sub2 card ' || i, parent.title),
        'description', random()::text,
        'parent_id', parent.card_id
    )
    from generate_series(1, 6) i, sub1_card as parent
    returning aggregate_id as card_id, payload->>'title' as title
)
, board as (
    insert into message
    (type, topics, aggregate_id, payload) select
    'card_added_to_layer', array['card', 'layer', 'board'], card_id, json_build_object(
        'layer_id', layer_id
    )
    from
        (table root_card union all table sub1_card union all table sub2_card) any_card,
        (table root_layer union all table sub1_layer union all table sub2_layer) any_layer
    returning *
)
select count(*) from board;

commit;
