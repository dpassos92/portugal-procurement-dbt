select
    idcontrato,
    precoContratual as preco_contratual,
    precoBaseProcedimento as preco_base_procedimento,
    PrecoTotalEfetivo as preco_total_efetivo
from {{ ref('stg_contratos') }}