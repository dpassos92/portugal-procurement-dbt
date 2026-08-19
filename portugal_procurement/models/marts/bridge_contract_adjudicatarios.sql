select distinct
    idcontrato,
    entity_key,
from {{ref('int_entities')}}
where role = 'adjudicatario'