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
Raw data contains 226,998 rows with 225,920 distinct idcontrato values, leaving 1,078 duplicated rows (0.47%), across 1,066 duplicate idcontrato groups (1,113 pairwise comparisons once group sizes >2 are accounted for — one contract, 10804349, was republished 9 times). Checked every column pairwise across all 1,066 groups, not just a sample:
- 70 pairs are byte-for-byte identical across all 39 columns — pure re-publish noise. 36 of these 70 come from the single 9-row idcontrato = 10804349.
- 921 pairs differ in exactly one field: ContratEcologico (e.g. idcontrato = 10532672, "Não" -> "Sim")
- 122 pairs differ in exactly one field: TipoCriterioAdjudicacao
- 0 pairs have both fields differ at once
- no other column, across any group, ever differs
Checked dataPublicacao, dataCelebracaoContrato and dataDecisaoAdjudicacao specifically as a possible tiebreak signal, all three are identical between duplicate rows in every pair checked, so they represent the contract's own dates, not a per-row edit timestamp. No timestamp signal exists anywhere in the schema to say which duplicate is current.

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
Adjudicatarios shows the same ID/name problem as adjudicante, more severely. The worst real-ID case (504615947, MEO) has 72 distinct name variants -- mostly cosmetic (case, punctuation, en-dash vs hyphen), but also a structural artifact (~210 entries carry a stray "1 - " prefix baked into the name itself, likely a leaked lot/item number). "NEC Portugal - Telecomunicações e Sistemas SA" and "ALTICE, S.A." (MEO's own parent company) also appear once each under MEO's id -- checked further: NEC Portugal has its own consistent id elsewhere (501676309, confirmed across 7 other contracts), so this is a genuine id/name mismatch on one row, cause unconfirmed (not a joint-award/consortium case -- the array is single-element, no MEO name alongside it). Not a one-off: checking systematically, 45 distinct real company names are paired with more than one entity_id across the dataset, always the same shape -- one dominant, well-established id plus a rare stray mismatch (Medtronic Portugal: 615 vs 2; Merck Sharp Dohme: 264 vs 1; Smith & Nephew: 313 vs 3). One case all but confirms these are entry typos rather than something more exotic: "Ronsegur - Rondas e Segurança, S.A." pairs with 507011724 (x31) and 507017724 (x1) -- the two ids differ by one transposed digit.

A second, previously-undocumented problem: 9.6% of adjudicatarios entries (22,286 / 231,215) use a literal "-" as the id -- not because they're all individuals, but because the id is simply unavailable for two different populations: Portuguese individual/sole-trader contractors, and foreign companies without a Portuguese NIF. 2,391 distinct names repeat within this placeholder group (7,581 entries, ~34%), and the top repeats are recognisable foreign medical/pharma suppliers (TERUMO EUROPE ESPANHA SL x157, CEPHEID IBERIA x96, AVANOS MEDICAL BELGIUM x73) -- confirming most of the repeat volume is real recurring entities, not name collisions between different individuals. The same cosmetic drift problem exists inside this group too: EBSCO alone appears under 7 different spellings, all under the same placeholder id. A handful of rows (3x "- - 500043256") have neither a usable id nor a real name -- just a NIF-looking number in the name slot, a genuine source gap.
CPV, however, is a different scenario: it's a fixed classification code (Common Procurement Vocabulary), not an organizational identity, and checking it confirmed that every CPV code maps to exactly one description, no drift.

## Dimensionally structured
Locations up to 218, CPV codes up to 40 per contract — real bridge-table territory, not flattenable.

## Design decisions arising from this
Within-snapshot duplicates: 9 identical rows for the same idcontrato within a single pull (e.g. 10804349) are straightforward re-publish noise, deduplicated directly (DISTINCT / ROW_NUMBER) before anything else happens to the data. For the pairs that aren't identical, there's no signal to say which row is current (see Complete), so the dedup uses a deterministic but arbitrary tiebreak: `order by ContratEcologico, TipoCriterioAdjudicacao` picks the same row every run, doesn't claim to know which value is "right."

Cross-time changes: rather than picking one "current" row and discarding the rest, track changes with a dbt snapshot using the check strategy, scoped to ContratEcologico, TipoCriterioAdjudicacao, precoContratual, dataFechoContrato, and the normalized entity name — not check_cols: 'all', and not the raw adjudicante/adjudicatarios string.
The snapshot runs against a cleaned staging model where whitespace and punctuation are already normalized, so cosmetic drift (e.g. "E. P. E." vs "E.P.E") doesn't get flagged as a real change alongside genuine ones (e.g. the ContratEcologico correction, or the Hospital -> ULS Alentejo Central rename).

Array fields: staging keeps arrays close to the source shape. Marts unnests them into a star schema: fct_contracts as the fact table, dim_entities for adjudicante/adjudicatarios, dim_cpv for CPV codes, and bridge_contract_locations / bridge_contract_cpv as junction tables for the many-to-many relationships.

dim_entities key resolution: use the real id when present; fall back to the normalized name when id = "-", since that placeholder covers both individuals and foreign companies and can't be trusted as a shared key on its own (see Atomic). Name normalization (case-fold, strip legal-suffix punctuation, collapse whitespace, strip a leading numeric "<n> - " artifact prefix) runs before dedup either way, since cosmetic drift showed up in both the real-id and placeholder groups. The 45 cases where a real id/name pairing has a rare stray mismatch (see Atomic) are not corrected -- documented and accepted, not majority-vote resolved.

Null vs. empty string: coerce blank strings to NULL in staging, so nothing downstream has to check both representations for "missing."

Not fully solving: the source has no true update timestamp, so a snapshot's valid_from reflects when the pipeline detected the change, bounded by the 15-day pull cadence, not necessarily when the change actually happened at the source. Also not solving: the "Concurso limitado por prévia qualificação" anomaly (28.8% blank nAnuncio, no clean explanation found); the 45 cases of a real entity id paired with a rare stray mismatched id (e.g. NEC Portugal, Ronsegur), left as-is rather than majority-vote corrected; two different individuals who happen to share an identical name would incorrectly merge under the placeholder-group name key; and 3 rows (e.g. "- - 500043256") have neither a usable id nor a real name, just a NIF-looking number in the name slot.

