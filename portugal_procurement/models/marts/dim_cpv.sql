select distinct
    cpv_code,
    cpv_description_raw as cpv_description
from{{ref("int_cpv")}}