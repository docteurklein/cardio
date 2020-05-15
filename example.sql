set search_path = cardio;

select card_id, name from card where card_id = :'card_id';

-- find all descendants of :card_id:
select card_id, name descendant from card join card_with_ancestors using (card_id) where ancestors @> array[:'card_id']::uuid[];

-- find all ancestors of :card_id:
select card_id, name ancestor from card where card_id in (select unnest(ancestors) from card_with_ancestors where card_id = :'card_id');

-----

select layer_id, name from layer where layer_id = :'layer_id';

-- find all descendants of :layer_id:
select layer_id, name descendant from layer join layer_with_ancestors using (layer_id) where ancestors @> array[:'layer_id']::uuid[];

-- find all ancestors of :layer_id:
select layer_id, name ancestor from layer where layer_id in (select unnest(ancestors) from layer_with_ancestors where layer_id = :'layer_id');
