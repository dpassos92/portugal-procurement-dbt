with source as (
    select * from {{ source('raw', 'contratos') }}
),

cleaned as (
    select
        * exclude (nAnuncio, TipoAnuncio, idINCM),
        nullif(nAnuncio, '') as n_anuncio,
        nullif(TipoAnuncio, '') as tipo_anuncio,
        nullif(idINCM, '') as id_incm
    from source
),

deduped as (
    select
        *,
        row_number() over (
            partition by idcontrato
            order by ContratEcologico, TipoCriterioAdjudicacao
        ) as rn
    from cleaned
)

select * exclude (rn)
from deduped
where rn = 1