select 
    idcontrato,
    country,
    district,
    municipality,
from{{ ref('int_locations') }}