with unnested as (
    select unnest(adjudicatarios) as raw
    from {{ source('raw', 'contratos') }}
),
split as (
    select
        trim(regexp_extract(raw, '^(.*?) - (.*)$', 1)) as entity_id,
        trim(regexp_extract(raw, '^(.*?) - (.*)$', 2)) as entity_name
    from unnested
)

select 'MEO variants' as example, entity_name, count(*) as n
from split
where entity_id = '504615947'
group by entity_name

union all

select 'placeholder repeats' as example, entity_name, count(*) as n
from split
where entity_id = '-'
group by entity_name
having count(*) > 1

order by example, n desc