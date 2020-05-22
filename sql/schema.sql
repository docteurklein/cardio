begin;

create schema if not exists cardio;

set search_path = cardio;

create or replace function uuid4() returns uuid
language sql parallel safe strict as $$
select extensions.uuid_generate_v4();
$$;

create table if not exists migration (id bigint primary key, reason text not null, at timestamptz not null default clock_timestamp());

create or replace function migrate() returns bigint
language plpgsql as $_$
declare current bigint;
begin
    select coalesce((select id from migration order by id desc limit 1), 0) into current;
    raise notice 'current "%"', current;

    case when current < 1 then
        create table card (
            card_id uuid primary key default uuid4(),
            parent_id uuid references card (card_id),
            name text not null,
            description text not null
        );

        create table layer (
            layer_id uuid primary key default uuid4(),
            parent_id uuid references layer (layer_id),
            name text not null,
            description text not null
        );

        create table card_in_layer (
            card_id uuid references card (card_id),
            layer_id uuid references layer (layer_id)
        );

        insert into migration (id, reason) values (1, 'initial schema for card and layer');
    else null;
    end case;

    case when current < 2 then
        create recursive view card_with_ancestors (card_id, parent_id, name, description, ancestors, level) as
            select card_id, parent_id, name, description, '{}'::uuid[], 1
            from card
            where parent_id is null
            union all
            select sub.card_id, sub.parent_id, sub.name, sub.description, ancestors || sub.parent_id, level + 1
            from card sub
            join card_with_ancestors p on (p.card_id = sub.parent_id)
        ;

        create recursive view layer_with_ancestors (layer_id, parent_id, name, description, ancestors, level) as
            select layer_id, parent_id, name, description, '{}'::uuid[], 1
            from layer
            where parent_id is null
            union all
            select sub.layer_id, sub.parent_id, sub.name, sub.description, ancestors || sub.parent_id, level + 1
            from layer sub
            join layer_with_ancestors p on (p.layer_id = sub.parent_id)
        ;

        insert into migration (id, reason) values (2, 'recursive views to query graph');
    else null;
    end case;

    case when current < 3 then
        create role web_anon nologin;

        grant usage on schema cardio to web_anon;
        grant usage on schema extensions to web_anon;
        grant select on cardio.card to web_anon;
        grant select on cardio.layer to web_anon;
        grant select on cardio.card_in_layer to web_anon;
        grant select on cardio.card_with_ancestors to web_anon;
        grant select on cardio.layer_with_ancestors to web_anon;

        insert into migration (id, reason) values (3, 'add roles for postgrest');
    else null;
    end case;

    case when current < 4 then
        alter table card rename column name to title;
        alter table layer rename column name to title;

        drop view card_with_ancestors;
        create recursive view card_with_ancestors (card_id, parent_id, title, description, ancestors, level) as
            select card_id, parent_id, title, description, '{}'::uuid[], 1
            from card
            where parent_id is null
            union all
            select sub.card_id, sub.parent_id, sub.title, sub.description, ancestors || sub.parent_id, level + 1
            from card sub
            join card_with_ancestors p on (p.card_id = sub.parent_id)
        ;

        drop view layer_with_ancestors;
        create or replace recursive view layer_with_ancestors (layer_id, parent_id, title, description, ancestors, level) as
            select layer_id, parent_id, title, description, '{}'::uuid[], 1
            from layer
            where parent_id is null
            union all
            select sub.layer_id, sub.parent_id, sub.title, sub.description, ancestors || sub.parent_id, level + 1
            from layer sub
            join layer_with_ancestors p on (p.layer_id = sub.parent_id)
        ;

        insert into migration (id, reason) values (4, 'rename title column');
    else null;
    end case;

    case when current < 5 then
        alter table card add column created_at timestamptz not null default clock_timestamp();
        alter table card add column updated_at timestamptz not null default clock_timestamp();

        alter table layer add column created_at timestamptz not null default clock_timestamp();
        alter table layer add column updated_at timestamptz not null default clock_timestamp();

        insert into migration (id, reason) values (5, 'add edit timestamps');
    else null;
    end case;

    case when current < 6 then
        create table message (
            message_id uuid primary key default uuid4(),
            type text not null,
            topics text[] not null,
            at timestamptz not null default clock_timestamp(),
            aggregate_id uuid not null,
            payload jsonb not null
        );
        create index on message (aggregate_id);

        create rule immutable_message as on update to message do instead nothing;
        create rule immortal_message as on delete to message do instead nothing;

        grant insert on cardio.message to web_anon;
        grant select on cardio.message to web_anon;

        create or replace function trigger_projection() returns trigger
        language plpgsql as $$
        begin
            perform project(new);
            return null;
        end;
        $$;

        create trigger on_message_insert after insert on message
        for each row execute function trigger_projection();

        insert into migration (id, reason) values (6, 'event sourcing');
    else null;
    end case;

    case when current < 7 then
        alter table card_in_layer add column added_at timestamptz not null default clock_timestamp();

        create or replace function trigger_projection() returns trigger
        language plpgsql as $$
        begin
            perform project_v2(new);
            return null;
        end;
        $$;

        drop function if exists project(message);

        insert into migration (id, reason) values (7, 'adapt projection to add card_in_layer timestamp');
    else null;
    end case;

    select coalesce((select id from migration order by id desc limit 1), 0) into current;
    return current;
end;
$_$;

select migrate() as current;

create or replace function project_v2(message message) returns void
language plpgsql as $$
begin
    perform pg_notify(topic, json_build_object(
        'sql', 'select row_to_json(message) from cardio.message where message_id = $1::uuid',
        'params', array[message.message_id]
    )::text) from unnest(message.topics || array['message_added', message.type, '*']) as topic;

    case message.type
        when 'card_created' then
            insert into card
            (card_id              ,  title                     ,  description                     ,  created_at,  updated_at) values
            (message.aggregate_id ,  message.payload->>'title' ,  message.payload->>'description' ,  message.at,  message.at);
        when 'layer_created' then
            insert into layer
            (layer_id             ,  title                     ,  description                     ,  created_at,  updated_at) values
            (message.aggregate_id ,  message.payload->>'title' ,  message.payload->>'description' ,  message.at,  message.at);
        when 'card_added_to_layer' then
            insert into card_in_layer
            (card_id              ,  layer_id                             , added_at) values
            (message.aggregate_id ,  (message.payload->>'layer_id')::uuid , message.at);
        else
            raise notice 'no projection for message "%"', message.type;
    end case;
end;
$$;

commit;
