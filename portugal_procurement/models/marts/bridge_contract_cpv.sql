select
    distinct idcontrato,
    cpv_code,
from {{ref("int_cpv")}}
