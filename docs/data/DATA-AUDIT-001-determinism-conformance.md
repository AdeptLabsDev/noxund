# DATA-AUDIT-001 — Determinism & Conformance Audit (channel-filter → scoring → opportunity + entity-resolution)

- **Task:** read-only adversarial audit of the landed deterministic pipeline against the ratified v1 (DEC-0017)
- **Owner:** Data/AI Pipeline reviewer (audit role)
- **Date:** 2026-07-02
- **Mode:** READ-ONLY. Zero code changed, zero compute on real data, zero API/network/secret/env/DB, zero collection, zero publish, zero commit. Static analysis of source + synthetic unit tests only (tests were **read**, not executed).
- **Source of truth:** `docs/product/decisions/DEC-0017-pipeline-v1-ratifications.md` (wins on any conflict) · `DATA-SCORING-001` · `DATA-CHANNEL-001` · `DATA-OPP-001` · `DATA-CONST-001` (proposal, superseded where DEC-0017 differs)
- **Code audited:** `services/data-engine/src/noxund_data_engine/{channel_filter,scoring,opportunity,entity_resolution,postgres_entity_resolution}.py` + `services/data-engine/tests/test_*.py`
- **Guardrails honored:** Fase 9 (RLS) VETOED — ignored. `0007`/`producer_events` PARKED — ignored. Weights 40/25/20/15 LOCKED — audited for presence, not re-questioned.

---

## 0. Executive summary

The landed code is a **faithful, high-quality implementation of DEC-0017**. Every ratified constant, curve, threshold, tie-break, rounding rule and normalization decision maps to code, and every product-number path is Decimal-exact, natural-key-ordered, and hash-frozen. **No P0 nondeterminism was found**: no wall clock, no floats, no set-iteration order, no randomness reaches any number or label.

Two conformance findings gate P5-REPRO-01 closure:

1. **DC2-01 (fail-closed on missing channel) is a GAP** — nothing in the landed code aborts when a channel needed by the run has no raw channel record; the Channel Filter silently degrades (self_channel cannot fire) and a unit test locks that tolerant behavior in. *(P1 — publish-gating)*
2. **`self_channel` is implemented but formally unratified** — DEC-0017 explicitly leaves it as an open item awaiting Product Lead confirmation, yet it is landed as active Gate 1 and frozen into `rule_hash`. *(P1 — ratification debt)* *(Superado — ver Adendo §6, 2026-07-16.)*

Everything else is PASS or P2 hygiene. Details below.

---

## 1. Conformance matrix — DEC-0017 §items 1–6 ↔ code

Verdicts: **PASS** (conforms) · **GAP** (unimplemented) · **DRIFT** (implemented differently). File paths relative to `services/data-engine/src/noxund_data_engine/`.

### 1.1 DEC-0017 item 1 — OPP-02 (HOT, honest cap of 2)

| Ratified rule | Code location | Verdict |
|---|---|---|
| HOT only if `Score > 90` (strict) | `opportunity.py:79` (`HOT_SCORE_MIN_EXCLUSIVE = 90`); `opportunity.py:527-529` (`final_score > config.hot_score_min_exclusive`) | **PASS** |
| Report shows 0, 1 or 2 HOT (at most 2, honest) | `opportunity.py:80` (`HOT_MAX = 2`); `opportunity.py:530` (`hot_candidates[: config.hot_max]`) | **PASS** |
| Never promote `Score <= 90` to fill a quota | strict `>` at `opportunity.py:528`; no fill/pad path exists | **PASS** — locked by test `test_never_promotes_score_equal_to_90` (`tests/test_opportunity.py:265`) |
| >2 cross 90 ⇒ only the top-2 by ranking key badge | HOT drawn from `displayed` which is already in ranking order; prefix = top set (`opportunity.py:523-530`) | **PASS** — test `test_hot_capped_at_two_when_more_than_two_cross_90` |

### 1.2 DEC-0017 item 2 — OPP-03 (ranking key)

| Ratified rule | Code location | Verdict |
|---|---|---|
| `final_score DESC → velocity_component DESC → signals_component DESC → artist_id ASC` | `opportunity.py:557-567` (`_ranking_key` returns `(-final_score, -norm_velocity, -norm_signals, artist_id)`) | **PASS** |
| Supersedes the `raw_score`-based key of DATA-OPP-001 §5 | code contains **no** `raw_score` in any ordering | **PASS** — note: `DATA-OPP-001` §5/§6.1 still document the superseded key (spec-refresh follow-up already logged in DEC-0017 "Spec-refresh design-only"; doc drift, not code drift) |
| Components are the normalized Score components, consumed verbatim | `_ranking_key` reads `score.components.norm_velocity / norm_signals` (`opportunity.py:564-566`); never recomputed | **PASS** |
| Total order (byte-stable) | final key `artist_id ASC` over unique ids (dupes rejected `opportunity.py:576-579`); inputs pre-sorted by `artist_id` (`opportunity.py:582`) | **PASS** |

### 1.3 DEC-0017 item 3 — OPP-06 (composition)

| Ratified rule | Code location | Verdict |
|---|---|---|
| Up to 10 qualified artists | `opportunity.py:82` (`MAX_REPORT_ITEMS = 10`); `opportunity.py:521` (`qualified[: config.max_report_items]`) | **PASS** — test `test_caps_at_ten_items` |
| Display gate `Score >= 83` | `opportunity.py:81` (`DISPLAY_GATE_MIN = 83`); qualification `opportunity.py:503-505` and `score_display` `opportunity.py:639-641`, both `>=` | **PASS** — DEC-0017 says `≥ 83`; code follows it. (`DATA-OPP-001` §7 says strict `> 83` — DEC-0017 wins; another spec-refresh item, boundary tested at 83/82 in `test_display_gate_83_boundary`) |
| <10 qualify ⇒ show fewer; never fill a slot below 83 | filter-then-slice at `opportunity.py:501-521`; no pad path | **PASS** — test `test_fewer_than_ten_qualified_shows_fewer` |
| All `< 83` ⇒ report marked `insufficient_opportunity`, zero items | `opportunity.py:507-519` (empty `items`, flag `True`, still carries frozen versions) | **PASS** — test `test_insufficient_opportunity_when_all_below_83` |
| Each report = its own `run_id` | `build_report` is keyed to exactly one `run_id` (`opportunity.py:475-482`) | **PASS (structural)** — the "2 fixed reports = 2 distinct runs" orchestration is not in the audited code (not landed anywhere); nothing contradicts it |

### 1.4 DEC-0017 item 4 — SCORING `score_rubric_2026_06_v1`

| Ratified rule | Code location | Verdict |
|---|---|---|
| Weights 40/25/20/15 (LOCKED) | `scoring.py:88-91`; sum-to-1 enforced `scoring.py:183-191`; formula `scoring.py:529-549` | **PASS** |
| `P_VEL = p90` | `scoring.py:94`; applied `scoring.py:608` | **PASS** |
| `P_ENG = p90` | `scoring.py:95`; applied `scoring.py:609` | **PASS** |
| `SIGNALS_SAT_CAP = 20` | `scoring.py:96`; applied `scoring.py:762` | **PASS** |
| `DIVERSITY_TARGET = 15` | `scoring.py:97`; applied `scoring.py:763-765` | **PASS** |
| `LAMBDA_REC` = half-life 15d (λ≈0.0462/day) | `scoring.py:98` (`HALF_LIFE_DAYS = 15`); `recency_weight` computes `exp(ln(0.5)·age/15)` ≡ `exp(−(ln2/15)·age)` (`scoring.py:435-450`) | **PASS** — half-life form is arithmetically identical to λ≈0.0462/day; verified by test `test_recency_weight_is_exponential_with_15_day_half_life` |
| `AGE_FLOOR_DAYS = 1` | `scoring.py:99`; `effective_age_days` (`scoring.py:395-405`) | **PASS** |
| Velocity/Engagement curve = percentile-anchor + cap `min(1, x/pP)` | `normalized_ratio` (`scoring.py:503-510`) + `_sample_relative` (`scoring.py:804-809`) + `_reference` p90 (`scoring.py:745-751`) | **PASS** |
| Velocity = per-artist **median** of views/day | `scoring.py:713-717` (median over per-video `views/age_eff`), median rule `scoring.py:453-464` (odd → central; even → exact mean of two central) | **PASS** — matches PRD §5.5 / DATA-SCORING-001 §5.3 |
| Signals/Diversity curve = ln-saturating `min(1, ln(1+n)/ln(1+cap))` | `ln_saturating` (`scoring.py:493-500`) | **PASS** |
| Recency = exponential `exp(−λ·age_eff)` | `recency_weight` (`scoring.py:435-450`), applied to engagement weights (`scoring.py:669-671`, `718-728`) | **PASS** |
| Final rounding `ROUND_HALF_UP` | `scoring.py:106` (`FINAL_ROUNDING`), `final_score_from_raw` quantize with explicit `ROUND_HALF_UP` (`scoring.py:552-560`) | **PASS** — 90.5→91 / 82.5→83 locked by test `test_final_score_rounds_half_up_at_90_5_and_83` |
| Normalization reference = artists of the run, no historical baseline | `score_run` builds `V_REF`/`E_REF` from this run's prepared artists only (`scoring.py:606-611`); `canonical()["reference_set"] = "run_scored_artists"` (`scoring.py:238`); refs frozen per-row in `metrics_detail_json.normalization` (`scoring.py:846-866`) | **PASS** — composition-dependence verified by test `test_run_relative_reference_composition_dependence` |
| Values + curves + percentile-interpolation method frozen into `rubric_hash`; any change ⇒ new `rubric_version` | `RubricConfig.canonical()` serializes weights, constants, curves, percentile method, recency method, precision, both rounding modes (`scoring.py:199-241`); `rubric_hash = sha256(canonical_json)` (`scoring.py:243-249`) | **PASS** — hash sensitivity to each knob locked by `test_rubric_hash_is_sensitive_to_each_constant` |
| NULL never coerced to 0 (per-component policy) | views NULL → out of Velocity+Engagement (`scoring.py:676-678`); views 0 → out of Engagement only (`scoring.py:689-693`); likes/comments NULL → absent numerator contribution (`scoring.py:430`); NULL component → norm 0, column NULL (`scoring.py:804-809`) | **PASS** — tests `test_all_null_views_…`, `test_null_views_distinct_from_zero_views` |

### 1.5 DEC-0017 item 5 — CHANNEL `channel-filter-v1` (minimalist)

| Ratified rule | Code location | Verdict |
|---|---|---|
| `MAX_RUN_VIDEOS_PER_CHANNEL = 60` — the only active **quantitative** gate | `channel_filter.py:44` (`= 60`); strict `> 60` ⇒ ineligible, exactly 60 stays eligible (`channel_filter.py:352-356`) | **PASS** — no code anywhere uses the DATA-CONST-001 proposal of 50; boundary 60/61 locked by `test_run_domination_boundary_60_eligible_61_ineligible` |
| `MIN_PUBLIC_UPLOADS` disabled | listed in `_DISABLED_GATES` (`channel_filter.py:53-58`); `ChannelRecord.upload_count` carried but never evaluated (`channel_filter.py:136-149`) | **PASS** — `test_disabled_gates_do_not_fire_…` proves a 1-upload/0-subs/0-views/dup-titles channel stays eligible |
| `MIN_SUBS` / `MIN_CHANNEL_VIEWS` disabled | same as above (`MIN_SUBSCRIBERS`, `MIN_CHANNEL_VIEWS` in `_DISABLED_GATES`); never read in `_classify` | **PASS** — cosmetic naming note: DEC-0017 says `MIN_SUBS`, code says `MIN_SUBSCRIBERS` (hash covers the code name; no semantic drift) |
| `DUP_TITLE_CAP` disabled/removed | in `_DISABLED_GATES`; video `title` carried but never evaluated (`channel_filter.py:118-133`) | **PASS** |
| Disabled gates frozen into the hash so re-enabling forces a new `rule_version` | `canonical()["constants"]` serializes each disabled gate (`channel_filter.py:91-106`) | **PASS** |
| Supersedes the 4-gate ordered set of DATA-CHANNEL-001 §5.2 | only 2 gates exist in code (`_classify`, `channel_filter.py:329-360`); `insufficient_history`/`spam_burst`/`low_channel_signal` reason codes do **not** exist (`ReasonCode`, `channel_filter.py:61-67`) | **PASS** — allow-list closure locked by `test_reason_code_allow_list_is_closed_to_v1` |
| **`self_channel` exclusion** | implemented as active **Gate 1** (`channel_filter.py:345-350`), exact normalized match reusing `normalize_for_match` (`channel_filter.py:255-264`, `362-369`), frozen into `rule_hash` (`channel_filter.py:97-100`) | **⚠ OPEN / conformance risk** — DEC-0017 item 5 does **not** ratify `self_channel`; the DEC's "Itens abertos remanescentes" explicitly says it *awaits Product Lead confirmation* (Orchestrator recommends keeping it). The code lands the recommendation as live rule. See finding **P1-02**. |

### 1.6 DEC-0017 item 6 — DC2-01 (deleted/suspended channel ⇒ fail-closed)

| Ratified rule | Code location | Verdict |
|---|---|---|
| If `channels.list` does not return a channel needed by the run, the run **aborts / requires recollection as a new `run_id`** (no tombstone) | **no implementation anywhere in the audited code.** `ChannelFilter.evaluate_run` accepts `channels: Sequence[ChannelRecord] = ()` (`channel_filter.py:284-296`) and silently proceeds when a judged channel has no record: `titles.get(channel_id)` → `None` → normalized `""` → `self_channel` can never fire (`channel_filter.py:305, 311`). Test `test_channel_without_record_has_no_title_signal` (`tests/test_channel_filter.py:310-321`) **locks in** the tolerant behavior. | **GAP** — see finding **P1-01** |

### 1.7 Competition thresholds (LOCKED upstream — methodology L194-196 / PRD L207-209, cited by DEC-0017)

| Locked rule | Code location | Verdict |
|---|---|---|
| Low `<= 5` / Medium `6..15` / High `> 15` | `opportunity.py:85-86`; `base_competition_level` (`opportunity.py:357-364`) | **PASS** — boundaries 5/6/15/16 locked by `test_base_level_bucket_boundaries` |
| OR 7d publication growth `> 50%` ⇒ High (raise-only) | `opportunity.py:87-89`; `growth_trigger` strict `growth > threshold` (`opportunity.py:392-409`); raise-only at `opportunity.py:677` | **PASS** |
| `prior_7d = 0` ⇒ no-trigger (fail-closed) | `opportunity.py:399-406` returns `(False, None)`; rule string locked in config (`opportunity.py:187-188`) | **PASS** — test `test_growth_prior_zero_is_no_trigger` |
| 7d windows anchored to `window_end`, half-open, never wall clock | `publication_windows` (`opportunity.py:367-389`): `(end−7d, end]` and `(end−14d, end−7d]` | **PASS** — boundary ownership locked by `test_publication_windows_half_open_anchored_to_window_end` |

### 1.8 Example selection (methodology §8 / PRD §5.7, consumed rule set)

| Rule | Code location | Verdict |
|---|---|---|
| Candidates = ValidVideos; `vel` consumed, never recomputed | `ValidVideo.vel` is an input (`opportunity.py:255-270`); ValidVideos must equal `score.contributing_video_ids` (`opportunity.py:594-597`) | **PASS** |
| Order `vel DESC, video_id ASC` → top-3; no-views candidate orders last | `_velocity_sort_key` (`opportunity.py:412-417`); `_example` (`opportunity.py:690-705`) | **PASS** — tests cover ordering + forced inclusion when <3 vel'd candidates |
| Winner: most recent `published_at` → max views → min `video_id` | `_example_cmp` total order (`opportunity.py:426-436`) | **PASS** — all three tie-break levels tested (`applied` = primary/secondary/final) |
| `selection_reason_json` satisfies F5-05A by construction | `_selection_reason_json` (`opportunity.py:707-762`) emits `candidates`(≥1)/`top3`(≥1)/`tiebreak`/`selected_example.video_id`; ≥1 candidate guaranteed by `_validate_artist` (`opportunity.py:587-588`) | **PASS** — Python mirror of the SQL validator asserted in tests |

---

## 2. Nondeterminism catalog

Verdict per source: **SAFE** (cannot move a product number/label) or **AT-RISK** (with evidence).

| # | Source | Verdict | Evidence |
|---|---|---|---|
| N1 | **dict/set iteration order in Competition/Diversity distinct-channel counting** | **SAFE** | `channel_filter._project` uses sets for dedup only; every emitted collection is `tuple(sorted(...))` (`channel_filter.py:406-413`) and channels are judged in `sorted(footprint)` order (`channel_filter.py:316`). Scoring/Opportunity *consume* the counts (`ArtistProjection.signals/competition` are `len()` of sorted tuples, `channel_filter.py:181-187`) and never re-derive them from an unordered container. `hot_ids` (`opportunity.py:530`) and `_rubric_identity`'s set (`opportunity.py:603-610`, exactly 1 element enforced) are membership-only. |
| N2 | **Percentile interpolation method + tie handling at p90** | **SAFE** | Exactly one frozen rule: linear interpolation, inclusive (type-7 / numpy `linear` / `PERCENTILE.INC`) — `percentile_inclusive` (`scoring.py:467-490`), identifier frozen into `rubric_hash` (`scoring.py:103`, `231-237`). Values are `sorted()` Decimals; duplicates are handled by order statistics (equal values are interchangeable, so DATA-CONST-001 §3.1's "stable artist_id tie-break" is satisfied vacuously — the anchor value cannot depend on which equal value sits where). `int(rank)` truncation of a non-negative Decimal is deterministic. Effective `V_REF`/`E_REF` are frozen per-row in `metrics_detail_json.normalization` for isolated replay (`scoring.py:846-859`). |
| N3 | **ROUND_HALF_UP vs Python banker's rounding (`round()`) vs Decimal** | **SAFE** | The public integer is produced *only* by `Decimal.quantize(..., rounding=ROUND_HALF_UP)` (`scoring.py:552-560`); builtin `round()` (half-even on floats) appears nowhere in a numeric path. Intermediates run under one frozen `Context(prec=50, ROUND_HALF_EVEN)` (`scoring.py:123`, `251-254`) — both modes and the precision are inside `rubric_hash` (`scoring.py:231-237`). `format_velocity_display` also uses explicit `ROUND_HALF_UP` quantize and is frozen into `opportunity_hash` (`opportunity.py:224-232`, `439-457`). Boundary behavior (90.5→91, 82.5→83) is test-locked. |
| N4 | **Tie-break stability / total ordering of the ranking key** | **SAFE** | `_ranking_key` = `(-int, -Decimal, -Decimal, str)` (`opportunity.py:557-567`): Decimal negation is exact (sign flip, no rounding); the final `artist_id ASC` over duplicate-rejected ids makes the order total, so `sorted()` stability is never even needed. Example ordering ends in `video_id` at both stages (`opportunity.py:412-417`, `426-436`). Scoring's own output order is the natural key `artist_id` (`scoring.py:631`), explicitly *not* a ranking (test `test_scoring_does_not_leak_opportunity_fields`). |
| N5 | **Float accumulation order** | **SAFE** | No IEEE-754 float ever enters a product number: ages come from integer `timedelta` fields (`scoring.py:378-392`), all arithmetic is `Decimal` under the frozen context, and `Decimal.ln`/`Decimal.exp` are correctly rounded per the General Decimal Arithmetic spec (`scoring.py:435-450`; non-integer `Decimal.__pow__` deliberately avoided). Accumulation order in `weighted_average` (`scoring.py:513-526`) is fixed by prior `video_id` sort (`scoring.py:718-728`), and the velocity median input is sorted (`scoring.py:713-717`) — so even the (order-sensitive in principle) fixed-precision addition happens in one frozen order. |
| N6 | **`age_floor` at 1 day** | **SAFE / one AT-RISK note** | Floor applied uniformly (`scoring.py:395-405`), protects `views/age` div-by-zero and the recency weight cap. **AT-RISK note:** a `published_at` *after* `window_end` (impossible in a well-formed run, but not rejected) produces a negative raw age that is silently floored to 1 day and scored as a fresh video — a masked upstream contract violation rather than nondeterminism. Fix direction in **P2-02**. |
| N7 | **Division-by-zero / empty-run guards** | **SAFE / one AT-RISK note** | `median`/`percentile_inclusive` raise on empty input (`scoring.py:456-457`, `476-477`); `weighted_average` guards zero total weight (`scoring.py:524-525`; weights are `exp(...)` > 0 anyway); `velocity_ratio` denominator ≥ AGE_FLOOR > 0; `growth_trigger` returns `(False, None)` on `prior_7d == 0` (`opportunity.py:399-406`); `_sample_relative` maps `None`/non-positive anchor to 0, never a fabricated statistic (`scoring.py:804-809`); all-zero velocities ⇒ `V_REF = 0` ⇒ all norms 0, deterministically. **AT-RISK note:** `score_run(artists=[])` silently returns an empty `RunScoreResult` (`scoring.py:605-618`) while `OpportunityBuilder` *raises* on an empty run (`opportunity.py:573-574`) — asymmetric fail-open vs fail-closed; see **P2-01**. |
| N8 | **Reliance on input row order** | **SAFE** | Every entry point canonicalizes: scorer sorts artists by `artist_id` (`scoring.py:621-631`) and videos by `video_id` (`scoring.py:662`); the filter judges channels in sorted order (`channel_filter.py:316`) and emits sorted projections; Opportunity sorts by `artist_id` before ranking (`opportunity.py:582`). Duplicates (artist or video) are `ContractViolation`s, and scoring/opportunity cross-check the exact video set against the upstream projection/`contributing_video_ids` (`scoring.py:648-651`, `opportunity.py:594-597`). Determinism-under-shuffle is test-locked (`test_tiebreak_velocity_then_signals_then_artist_id` shuffles input). |
| N9 | **Wall clock / timezone** | **SAFE** | The only temporal reference is the frozen `window_end`; naive datetimes are rejected everywhere (`scoring.py:145-149`, `opportunity.py:135-139`). No `now()`/`today()` call exists in the audited modules. Test suites pin `WINDOW_END` in the past specifically so a wall-clock leak would diverge. |
| N10 | **LLM (Entity Resolution)** | **SAFE by architecture / one AT-RISK note** | The LLM is reached only after persisted replay facts and the pending queue are checked (`entity_resolution.py:271-280`), never decides acceptance (its candidates land as `REVIEW_REQUIRED` pending rows, `entity_resolution.py:335-347`), never emits a numeric field (one-field JSON contract, `entity_resolution.py:214-226`), and every candidate passes the deterministic title-span guard (`entity_resolution.py:159-170`, re-checked on replay `entity_resolution.py:401-413`). So no LLM nondeterminism can reach a product number. **AT-RISK note:** a *transient* adapter failure (`llm_call_failed`, `entity_resolution.py:318-323`) is persisted as a **terminal rejected replay fact** — deterministic on replay, but a network blip permanently rejects that `(run, video, resolver_version)`; see **P2-03**. |
| N11 | **Postgres replay ordering** | **SAFE** | `_GET_FINAL_FACT_SQL` orders `created_at desc, id desc` (`postgres_entity_resolution.py:75`) — a total order over persisted rows, so the same table state always replays the same fact (the uuid tiebreak is arbitrary but stable). Writers are parameterized, natural-key addressed, and the automated writer cannot bind `artist_id`/`review_notes` (`postgres_entity_resolution.py:167-181`). |
| N12 | **Hash/canonical-JSON stability** | **SAFE** | `canonical_json` = sorted keys, no whitespace, `ensure_ascii=False` in all three modules; hashes are computed from config only (not data), and each test suite asserts hash stability across independently constructed configs and sensitivity to every knob. `str(Decimal)` is a deterministic function of the computed value (exponent + digits), so the evidence JSON is byte-stable given byte-stable arithmetic. |

---

## 3. Edge-case coverage assessment

| Edge case | Behavior in code | Correct? | Test coverage |
|---|---|---|---|
| **Empty run** | Scoring: `score_run(artists=[])` returns an empty result **silently** (`scoring.py:605-618`). Opportunity: raises `ContractViolation` (`opportunity.py:573-574`). | Opportunity: yes (fail-closed). Scoring: **questionable** — silent empty output can mask an upstream failure (see P2-01). | Opportunity: **covered** (`test_contract_violations_are_rejected`, `_build([])`). Scoring: **NOT covered** — no test pins the empty-input behavior. |
| **All scores < 83 (`insufficient_opportunity`)** | Flag `True`, `items = ()`, status stays `draft`, frozen versions still carried (`opportunity.py:507-519`). | Yes — matches DEC-0017 item 3. | **Covered** (`test_insufficient_opportunity_when_all_below_83`), including version carriage on the empty report. |
| **< 2 HOT** | 0 or 1 HOT emitted honestly; `Score == 90` never promoted (`opportunity.py:523-530`). | Yes. | **Covered** (`test_one_hot_when_only_one_crosses_90`, `test_zero_hot_when_none_cross_90`, `test_never_promotes_score_equal_to_90`). |
| **Single-channel domination at exactly 60** | Exactly 60 distinct videos ⇒ eligible; 61 ⇒ `run_domination` (`channel_filter.py:44`, `352-356`; strict `>`). | Yes — DEC-0017's "60 is the cap" with strict-greater ineligibility, dedup by `video_id` (`channel_filter.py:237-243`). | **Covered** (`test_run_domination_boundary_60_eligible_61_ineligible`, plus `test_null_channel_stats_are_not_treated_as_zero` at 61). |

Additional coverage gaps found (no behavior bug, missing lock-in):

- **Growth trigger at exactly 50%** — `growth == 0.50` must NOT fire (strict `>`); tests only exercise 100% growth and prior-zero. *(P2-04)*
- **`published_at > window_end`** — silently floored; untested and arguably should raise. *(P2-02)*
- **No chained integration test** `channel_filter → scoring → opportunity` proving the projections/`contributing_video_ids` handshake end-to-end on one synthetic run (each boundary is contract-checked and unit-tested, but the full replay path P5-REPRO-01 will exercise is never composed in-tests). *(P2-05)*
- **DC2-01** — not only unimplemented; the existing test asserts the *tolerant* behavior, so a future fail-closed fix must consciously flip that test. *(P1-01)*

---

## 4. Prioritized findings

### P1 (conformance gaps that gate P5-REPRO-01 / first publish)

**P1-01 — DC2-01 fail-closed is unimplemented; the Channel Filter silently degrades when a judged channel has no raw channel record. [GAP]**
- **Where:** `channel_filter.py:284-296` (`channels: Sequence[ChannelRecord] = ()` default), `channel_filter.py:305,311` (`titles.get(channel_id)` → `None` → `self_channel` disarmed); behavior locked in by `tests/test_channel_filter.py:310-321`.
- **Why it breaks conformance:** DEC-0017 item 6 ratifies *abort / recollect as a new `run_id`* when `channels.list` misses a needed channel. In the landed code a missing record is indistinguishable from "channel with no title": the run proceeds, `self_channel` cannot fire for that channel, and Competition/Signals are computed on a silently degraded basis — a fail-open path inside a fail-closed contract, producing plausible-looking but non-conformant numbers.
- **Minimal fix direction (describe only):** make the missing-record case explicit at the filter boundary — e.g. `evaluate_run` (or the future collection/orchestration layer that owns DC2-01) raises a `ContractViolation` when a judged `channel_id` has no `ChannelRecord` for the run, unless the caller explicitly passes a mode that only the gated collection pipeline may use. Update `test_channel_without_record_has_no_title_signal` to assert the fail-closed behavior. If the team decides DC2-01 belongs strictly to the collection layer, then (a) document that the filter *requires* a complete channel set as a precondition, and (b) still add the completeness assertion, because today no landed layer enforces it.

**P1-02 — `self_channel` is landed as an active gate but is formally unratified. [OPEN → conformance risk]**
- **Where:** `channel_filter.py:345-350` (Gate 1), frozen into `rule_hash` at `channel_filter.py:97-100`.
- **Why it matters:** DEC-0017 item 5 ratifies run-domination as "the only active quantitative gate" and explicitly parks `self_channel` under "Itens abertos remanescentes — aguarda confirmação do Product Lead". The code implements the Orchestrator's recommendation ahead of that confirmation and freezes it into `channel-filter-v1`'s hash. If the Product Lead declines (or amends matching semantics), the landed `channel-filter-v1` identity is wrong and must be reissued as a new `rule_version` — and any run computed meanwhile is non-conformant in Competition (self-channels excluded without ratified authority).
- **Minimal fix direction:** obtain the pending Product Lead confirmation and record it (a DEC addendum or DEC-0018) **before** any compute-live; no code change needed if confirmed as-is. If not confirmed, removing the gate is a `rule_version` bump (`channel-filter-v2`), never an in-place edit — exactly as the module's own docstring demands.

> **Adendo 2026-07-16 — finding SUPERADO.** A confirmação pedida já existia no registro (DEC-0017, emenda de 2026-07-01; DEC-0019 §1, 2026-07-02) e foi **reconfirmada pelo Product Lead em 2026-07-16**. Texto original preservado; ver §6.

### P2 (hygiene / hardening — deterministic today, but worth closing before live)

**P2-01 — `score_run` silently returns an empty result for an empty run.** *(FECHADO — U2 / PR #51; ver Adendo §7.)* `scoring.py:605-618`. Asymmetric with Opportunity's fail-closed `ContractViolation` (`opportunity.py:573-574`); a bug that filters out all artists upstream would yield a plausible empty run instead of an alarm. *Fix direction:* raise `ContractViolation` on `artists == ()` (a run reaching scoring has ≥1 scorable artist per DATA-SCORING-001 §3), or document the empty result as a legitimate contract and pin it with a test.

**P2-02 — `published_at` after `window_end` is silently floored to age 1.** *(FECHADO — U2 / PR #51; ver Adendo §7.)* `scoring.py:378-405`. A video "from the future" is a raw/collection contract violation; masking it as a fresh video is deterministic but wrong. *Fix direction:* raise `ContractViolation` when raw `age_days < 0` (the floor should protect near-zero ages, not negative ones). Add a test.

**P2-03 — Transient LLM failures are persisted as terminal rejected replay facts.** `entity_resolution.py:318-323` → `_record_llm_rejection` → `record_rejected_fact`. A network blip permanently rejects `(run, video, resolver_version)`; replay-deterministic but lossy — the video can never enter the review queue for that resolver version. *Fix direction:* distinguish transient adapter failure (do not persist; surface as retryable/needs_review-without-fact) from deterministic contract rejections (`llm_contract_violation`, `llm_no_single_candidate`, `candidate_outside_source_title`), which are correctly terminal.

**P2-04 — Growth-trigger boundary (exactly +50%) untested.** *(FECHADO — U2 / PR #51; ver Adendo §7.)* `opportunity.py:392-409` implements strict `>` correctly, but no test pins `growth_7d == 0.50 ⇒ no High`. *Fix direction:* add one boundary test (e.g. recent=3, prior=2).

**P2-05 — No end-to-end synthetic replay test across the three deterministic zones.** Each module has its own determinism test, but nothing composes `ChannelFilter.evaluate_run → PopularityScorer.score_run → OpportunityBuilder.build_report` on one synthetic run and asserts byte-identical double-execution — which is precisely the shape of the P5-REPRO-01 gate. *Fix direction:* add one integration test building the full chain twice from the same synthetic raw and comparing `RunFilterResult`/`RunScoreResult`/`OpportunityReport` for equality (they are frozen dataclasses; `==` is byte-equivalent given Decimal-exact fields).

**P2-06 — Spec-refresh debt (docs, not code).** `DATA-OPP-001` §5/§6.1 still document the superseded `raw_score` ranking/HOT key and the strict `> 83` display gate; `DATA-CHANNEL-001` §5.2 still documents the 4-gate rule set; DEC-0017 already schedules this refresh ("Spec-refresh design-only"). Until refreshed, a reader auditing code against those specs (instead of DEC-0017) would report false DRIFT. *Fix direction:* execute the scheduled design-only spec refresh.

**P2-07 — `velocity_display` seam just below 1000.** `opportunity.py:439-457`: a median of `999.6` formats as `1000/day` (whole-number rounding) while `1000` formats as `1.0k/day` — deterministic and hash-frozen, but the `k` threshold is checked before rounding, so "1000/day" and "1.0k/day" can both appear for adjacent values. Cosmetic only (PRD §5.5 doesn't pin this seam). *Fix direction (optional):* round first, then choose the format; would require an `opportunity_version` bump since formatting is hashed.

### OPEN questions (flagged, not guessed — for Product Lead / Data-AI)

- **OPEN-A — Percentile rule variant.** DEC-0017 ratifies that "the percentile interpolation method freezes into `rubric_hash`" but does not name the variant; DATA-CONST-001 §3.1 says "linear interpolation between adjacent ranks". The code pins **type-7 inclusive** (`scoring.py:103`, `467-490`) — a defensible, industry-default reading, frozen in the hash. Recommend a one-line ratification note (in the spec-refresh) naming type-7/inclusive explicitly so the DEC and hash agree in writing.
- **OPEN-B — Reference set vs NULL-velocity artists.** The p90 anchors are computed over artists with a *defined* raw value (`scoring.py:745-751`); an artist whose videos all lack `views` has no `vel_artist` and cannot enter the percentile. This is the only computable reading of "reference = the run's scored artists", and the effective `V_REF`/`E_REF` are frozen in the evidence — but the exclusion is worth one explicit sentence in the spec-refresh so it is ratified, not incidental.
- **OPEN-C — DC2-01 ownership.** Confirm which layer owns the abort (collection orchestration vs Channel Filter precondition) so P1-01 is fixed in the right place; today no landed layer owns it.

---

## 5. Success-criteria self-check

- Conformance matrix covers 100% of DEC-0017 §items 1–6 (plus the locked Competition/Example rule sets consumed by the code), each row with file:line and a PASS/GAP/DRIFT/OPEN verdict — §1.
- Nondeterminism catalog gives an explicit SAFE/AT-RISK verdict for every requested source (dict/set order, percentile method + p90 ties, rounding, ranking total order, accumulation order, age floor, div-by-zero/empty-run, input row order) plus LLM/DB replay — §2.
- Findings are ordered P1→P2 with file:line and minimal fix directions; **no code was changed, no pipeline was executed, no data was collected, nothing was published.**

---

## 6. Adendo (2026-07-16) — P1-02 superado pela ratificação registrada

**P1-02 está SUPERADO como finding.** Cadeia de registro, em ordem:

1. **2026-07-01** — a DEC-0017 foi emendada no mesmo dia da sua criação (commit `4be9519`, landed via PR #12) registrando **"self_channel — RATIFICADO: MANTER (Product Lead, 2026-07-01)"**. O finding refletiu o texto pré-emenda ("aguarda confirmação do Product Lead"); a ratificação é do dia anterior à data deste audit.
2. **2026-07-02** — a **DEC-0019 §1** resolveu formalmente o P1: `self_channel` ratificado como parte de `channel-filter-v1` — zero mudança de código, `rule_hash` inalterado, golden digest do harness preservado.
3. **2026-07-16** — o Product Lead **reconfirmou** a ratificação (`self_channel = MANTER`, "conforme ratificação de 2026-07-01") e ordenou esta reconciliação documental.

O texto original do finding (§0 item 2 e §4 P1-02) permanece **intacto acima**, por ordem expressa do Product Lead: este adendo apenas o marca como superado — nada foi reescrito retrospectivamente. **P1-01 não é tocado por este adendo** e permanece registrado como está, com tratamento em unidade própria.

*Registro relacionado:* DEC-0017 (linha de sequenciamento corrigida em 2026-07-16, mesma unidade documental) · DEC-0019 §1 · DEC-0021 (RO-1, mesma unidade documental).

---

## 7. Adendo (2026-07-21) — P2-01 / P2-02 / P2-04 fechados pelo U2 (PR #51)

**P2-01, P2-02 e P2-04 estão FECHADOS.** A unidade de hardening **U2** — **PR #51**, merge `0cced4f`, commit de implementação `c40b96d` — fechou os três, **hash-neutro por construção**:

- **P2-02 (código):** `age_days` levanta `ContractViolation("published_at must not be after window_end")` quando a idade bruta é `< 0`; `published_at == window_end` (idade 0) permanece válido, floorado a 1 por `effective_age_days`. É pré-condição de contrato de input (paralela a DEC-0022 no Channel Filter), **não** uma constante de rubric → **sem** `rubric_version` bump.
- **P2-01 (teste):** `test_empty_run_scores_empty_without_raising` registra `score_run(artists=())` como contrato legítimo — resultado vazio **sem** raise, com `rubric_version`/`rubric_hash` carimbados.
- **P2-04 (teste):** `test_growth_trigger_exactly_50pct_does_not_fire` trava o `>` estrito: exatamente +50% (recent 3 vs prior 2) **não** dispara High; logo acima (+100%) dispara.

**Inalterado (before == after):** `rule_version`/`rubric_version`/`opportunity_version`; `rule_hash` `7a1e3c76…eaea7`, `rubric_hash` `f0c465fb…3ca54`, `opportunity_hash` `ce7c7c1a…ba52f`; golden digest `c8e33fe8…74ca8` (byte-idêntico ×2 e == `GOLDEN_DIGEST`). Suíte 172 → 175 (×2 GREEN); repro harness 21 intacto. **Nenhum run bem-formado muda de output** — no dataset `f0485de6` (janela de 30d) nenhum vídeo tem `published_at > window_end`.

O texto original dos findings (§2 N6/N7, §3 e §4 P2-01/02/04) permanece **intacto acima**; este adendo apenas os marca como fechados — nada foi reescrito retrospectivamente. **P2-03, P2-05, P2-06 e P2-07 não são tocados** por este adendo (P2-05 já coberto pelo repro harness `test_repro_harness`; P2-06 endereçado no spec-refresh aditivo do U1/DEC-0023; P2-03 e P2-07 permanecem como registrados).

*Registro completo:* `docs/data/DATA-AUDIT-001-U2-p2-closeout.md`. *Relacionado:* DEC-0023 (D-D não-bloqueantes · D-E U2 antes do 1º compute) · DEC-0017 item 4 (rubric) · DEC-0022 (precedente de pré-condição fail-closed no Channel Filter). **Atribuição:** DEC-0021 é RO-1 e **não** fecha `self_channel`/P1-02 — o fechamento de P1-02 está em §6.
