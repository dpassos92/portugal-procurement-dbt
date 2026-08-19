with localExecucao_unnested as (
    select
        idcontrato,
        'localExecucao' as role,
        unnest(localExecucao) as raw
    from {{ ref('stg_contratos') }}
)


select
    idcontrato,
    str_split(raw, ', ') as parts,
    list_extract(str_split(raw, ', '), 1) as country,
    list_extract(str_split(raw, ', '), 2) as district,
    list_extract(str_split(raw, ', '), 3) as municipality
from localExecucao_unnested
  