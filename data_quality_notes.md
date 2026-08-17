# Data Quality Notes — Portuguese Public Procurement (base.gov.pt)

Source: https://dados.gov.pt/pt/datasets/contratos-publicos-portal-base-impic-contratos-de-2012-a-2026
Scope: 2024
Rows: 226,998 contracts (2024)

## Known pedigree
- Publisher: IMPIC (Instituto dos Mercados Públicos, do Imobiliário e da Construção), the regulatory body for public markets, publishes via base.gov.pt
- License: public domain (confirmed on the dados.gov.pt dataset page — "Licença: other-pd" / "Domínio Público")
- Distribution path: published on base.gov.pt, mirrored to dados.gov.pt (the national open data portal)

## Timely
Files are updated every 2 weeks (15 days). However, no update timestamp field exists. 
Since there's no way to know when a specific row last changed, I'm capturing dated snapshots at the same cadence the source publishes at, so real changes (like the ContratEcologico correction found in Complete) can be caught between pulls.

## Complete
Uniqueness/duplication:
Raw data contains 226,998 rows with 225,920 distinct idcontrato values, leaving 1,078 duplicated rows (0.47%). Two different behaviours are behind that number:
- some duplicates are byte-for-byte identical (e.g. idcontrato = 10804349, 9 identical rows)
- others are genuine updates where one field changed (e.g. idcontrato = 10532672, ContratEcologico flipped from "Não" to "Sim" between the two rows)
The latter behaviour is more problematic, since there's no way to verify which is the "current" row. No update timestamp exists in the dataset.

Field-level findings:
- idprocedimento is 0% null, fully populated, reliable
- nAnuncio: 84.5% blank (191,942 / 226,998), but this isn't random — it tracks procedure type almost perfectly. Open tenders (Concurso público) are 0.03% blank; direct-award/prior-consultation procedures are 100% blank. One exception that doesn't fit the pattern: "Concurso limitado por prévia qualificação" at 28.8% blank, unexplained.
- dataFechoContrato: 75.2% missing, plausibly because most 2024 contracts simply haven't closed yet — though this one was never actually verified the way the nAnuncio pattern was.

## Well-annotated
The source doesn't publish a field glossary explaining what each column means, and missingness isn't represented consistently. nAnuncio uses an empty string for "not applicable" while NUTs and Lotes use actual NULL for the same underlying situation.

## Consistent
idcontrato is a string while idprocedimento is a number, same ID semantics, inconsistent typing. The duplicate-row behaviour is inconsistent in the same way: a repeated idcontrato sometimes means an exact re-publish and sometimes means a real update to one field, with nothing in the data to tell the two apart (see Complete).

## Atomic
adjudicante and adjudicatarios fields combine two facts (ID + name), but name itself isn't clean (punctuation + whitespace variants) and unlike a simple formatting problem, some of the variation is real signal (entity renamed) not noise, so the fix isn't "just split and normalize," it's "split, normalize the cosmetic variants, but preserve name-over-time as meaningful."
Adjudicatarios shows the same ID/name problem as adjudicante, more severely. The worst case has 74 distinct names attached to one entity ID, versus 5 for adjudicante.
CPV, however, is a different scenario: it's a fixed classification code (Common Procurement Vocabulary), not an organizational identity, and checking it confirmed that every CPV code maps to exactly one description, no drift.

## Dimensionally structured
Locations up to 218, CPV codes up to 40 per contract — real bridge-table territory, not flattenable.

## Design decisions arising from this
Within-snapshot duplicates: 9 identical rows for the same idcontrato within a single pull (e.g. 10804349) are straightforward re-publish noise, deduplicated directly (DISTINCT / ROW_NUMBER) before anything else happens to the data.

Cross-time changes: rather than picking one "current" row and discarding the rest, track changes with a dbt snapshot using the check strategy, scoped to ContratEcologico, precoContratual, dataFechoContrato, and the normalized entity name — not check_cols: 'all', and not the raw adjudicante/adjudicatarios string.
The snapshot runs against a cleaned staging model where whitespace and punctuation are already normalized, so cosmetic drift (e.g. "E. P. E." vs "E.P.E") doesn't get flagged as a real change alongside genuine ones (e.g. the ContratEcologico correction, or the Hospital -> ULS Alentejo Central rename).

Array fields: staging keeps arrays close to the source shape. Marts unnests them into a star schema: fct_contracts as the fact table, dim_entities for adjudicante/adjudicatarios (ID as the key, name normalized), dim_cpv for CPV codes, and bridge_contract_locations / bridge_contract_cpv as junction tables for the many-to-many relationships.

Null vs. empty string: coerce blank strings to NULL in staging, so nothing downstream has to check both representations for "missing."

Not fully solving: the source has no true update timestamp, so a snapshot's valid_from reflects when the pipeline detected the change, bounded by the 15-day pull cadence, not necessarily when the change actually happened at the source. Also not solving: the "Concurso limitado por prévia qualificação" anomaly (28.8% blank nAnuncio, no clean explanation found).

