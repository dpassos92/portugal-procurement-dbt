with source_totals as (
    select
        idcontrato,
        any_value(precoContratual) as source_preco_contratual
    from {{ source('raw', 'contratos') }}
    group by idcontrato
)

select
    f.idcontrato,
    f.preco_contratual as fct_value,
    s.source_preco_contratual as source_value
from {{ ref('fct_contracts') }} f
join source_totals s on f.idcontrato = s.idcontrato
where f.preco_contratual != s.source_preco_contratual