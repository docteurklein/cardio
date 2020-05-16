set search_path = cardio;

-- which card
select card_id, name from card where card_id = :'card_id';

-- find all descendants of :card_id:
select card_id, name descendant from card_with_ancestors where ancestors @> array[:'card_id']::uuid[];

-- find all ancestors of :card_id:
select card_id, name ancestor from card where card_id in (select unnest(ancestors) from card_with_ancestors where card_id = :'card_id');

-- which layer
select layer_id, name from layer where layer_id = :'layer_id';

-- find all descendants of :layer_id:
select layer_id, name descendant from layer_with_ancestors where ancestors @> array[:'layer_id']::uuid[];

-- find all ancestors of :layer_id:
select layer_id, name ancestor from layer where layer_id in (select unnest(ancestors) from layer_with_ancestors where layer_id = :'layer_id');

-- find all cards of a layer
select card_id, card.name, layer.name from card join card_in_layer using (card_id) join layer using (layer_id) where layer_id = :'layer_id';
