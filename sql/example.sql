set search_path = cardio;

select card_id from card order by random() limit 1 \gset
select layer_id from layer order by random() limit 1 \gset

-- which card
select card_id, title from card where card_id = :'card_id';

-- find all descendants of :card_id:
select card_id, title descendant from card_with_ancestors where ancestors @> array[:'card_id']::uuid[];

-- find all ancestors of :card_id:
select card_id, title ancestor from card where card_id in (select unnest(ancestors) from card_with_ancestors where card_id = :'card_id');

-- which layer
select layer_id, title from layer where layer_id = :'layer_id';

-- find all descendants of :layer_id:
select layer_id, title descendant from layer_with_ancestors where ancestors @> array[:'layer_id']::uuid[];

-- find all ancestors of :layer_id:
select layer_id, title ancestor from layer where layer_id in (select unnest(ancestors) from layer_with_ancestors where layer_id = :'layer_id');

-- find all cards of a layer
select card_id, card.title, layer.title from card join card_in_layer using (card_id) join layer using (layer_id) where layer_id = :'layer_id';
