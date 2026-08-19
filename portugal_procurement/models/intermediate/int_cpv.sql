with cpv_unnested as (
    select
        idcontrato,
        'cpv' as role,
        unnest(cpv) as raw
    from {{ ref('stg_contratos') }}
),

split as (
    select
        idcontrato,
        role,
        trim(regexp_extract(raw, '^(.*?) - (.*)$', 1)) as cpv_code,
        trim(regexp_extract(raw, '^(.*?) - (.*)$', 2)) as cpv_description_raw
    from cpv_unnested
)

select
    idcontrato,
    role,
    cpv_code,
    cpv_description_raw,
from split