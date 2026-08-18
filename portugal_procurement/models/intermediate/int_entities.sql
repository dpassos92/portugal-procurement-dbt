with adjudicante_unnested as (
    select
        idcontrato,
        'adjudicante' as role,
        unnest(adjudicante) as raw
    from {{ ref('stg_contratos') }}
),

adjudicatario_unnested as (
    select
        idcontrato,
        'adjudicatario' as role,
        unnest(adjudicatarios) as raw
    from {{ ref('stg_contratos') }}
),

unnested as (
    select * from adjudicante_unnested
    union all
    select * from adjudicatario_unnested
),

split as (
    select
        idcontrato,
        role,
        trim(regexp_extract(raw, '^(.*?) - (.*)$', 1)) as entity_id,
        trim(regexp_extract(raw, '^(.*?) - (.*)$', 2)) as entity_name_raw
    from unnested
),

normalized as (
    select
        idcontrato,
        role,
        entity_id,
        entity_name_raw,
        regexp_replace(entity_name_raw, '^\d+\s*-\s*', '') as no_prefix,
        lower(regexp_replace(strip_accents(no_prefix), '[^\p{L}\p{N}]', '', 'g')) as entity_name_key
    from split
)

select
    idcontrato,
    role,
    entity_id,
    entity_name_raw,
    entity_name_key,
    case when entity_id = '-' then entity_name_key else entity_id end as entity_key
from normalized