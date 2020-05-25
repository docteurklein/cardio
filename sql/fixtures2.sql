\set ON_ERROR_STOP 1

set search_path = cardio;

begin deferrable;
set constraints card_parent_id_fkey deferred;

truncate card cascade;
truncate layer cascade;

with recursive hierarchy (card_id, title, parent_id, level) as (
    select uuid4(), 'root card', null::uuid, 1
    union all
    select uuid4(), concat_ws(' > ', hierarchy.title, 'sub card ' || level + 1 || '.' || i), hierarchy.card_id, level + 1
    from hierarchy, generate_series(1, 3) i
    where level < 6
)
-- select * from hierarchy;
insert into message
(type, topics, aggregate_id, payload) select
'card_created', array['card', 'board'], hierarchy.card_id, json_build_object(
    'title', hierarchy.title,
    'description', random()::text,
    'parent_id', hierarchy.parent_id
)
from hierarchy
returning *;

commit;
