
```
psql -f schema.sql
psql -f fixtures2.sql

sh ./dot/dot.sh \
    "select row_to_json(card) from cardio.card where card_id in (select unnest(ancestors) from cardio.card_with_ancestors \
    where title like '%4.2')" \
    | xdot -
```
