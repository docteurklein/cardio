begin;

create schema if not exists cardio;

set search_path = cardio, extensions;

create table if not exists migration (id bigint primary key, at timestamptz not null default clock_timestamp());

drop function if exists migrate;
create function migrate() returns bigint language plpgsql as $_$
declare current_migration bigint;
begin
    select coalesce((select id from migration order by id desc limit 1), 0) into current_migration;
    raise notice 'current_migration "%"', current_migration;

    case when current_migration < 1 then

        create table card (
            card_id uuid primary key default extensions.uuid_generate_v4(),
            parent_id uuid references card (card_id),
            name text not null,
            description text not null
        );

        create table layer (
            layer_id uuid primary key default extensions.uuid_generate_v4(),
            parent_id uuid references layer (layer_id),
            name text not null,
            description text not null
        );

        create table card_in_layer (
            card_id uuid references card (card_id),
            layer_id uuid references layer (layer_id)
        );

        insert into migration (id) values (1);
    else null;
    end case;

    case when current_migration < 2 then

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

        insert into migration (id) values (2);
    else null;
    end case;


    case when current_migration < 3 then

        create role web_anon nologin;

        grant usage on schema cardio to web_anon;
        grant select on cardio.card to web_anon;
        grant select on cardio.layer to web_anon;
        grant select on cardio.card_in_layer to web_anon;
        grant select on cardio.card_with_ancestors to web_anon;
        grant select on cardio.layer_with_ancestors to web_anon;

        insert into migration (id) values (3);
    else null;
    end case;

    case when current_migration < 4 then

        alter table card rename column name to title;
        alter table layer rename column name to title;

        insert into migration (id) values (4);
    else null;
    end case;

    select coalesce((select id from migration order by id desc limit 1), 0) into current_migration;
    return current_migration;
end;
$_$;

select migrate() as current_migration;

commit;
