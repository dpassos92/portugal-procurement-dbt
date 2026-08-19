with entities_grouped as (
    select
    entity_key,
    entity_name_clean,
    count(*) as n from {{ ref('int_entities') }}
    group by entity_key, entity_name_clean
),
deduped as (
    select
    entity_key,
    entity_name_clean,
    row_number() over (
            partition by entity_key
        order by n desc
    ) as rn
    From entities_grouped
)

select
    entity_key,
    entity_name_clean,
from deduped
where rn =1 