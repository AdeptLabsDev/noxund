#!/usr/bin/env python3
"""Reference-durability check - the mechanical limb of DEC-0040 D15.

WHAT THIS IS
------------
DEC-0040 D15 fixes one invariant:

    LINE NUMBER = LOCATOR / CONVENIENCE ONLY

A load-bearing authority reference identifies its target by (i) the stable
document path, (ii) a stable named anchor, and (iii) a short verbatim
quotation wherever the exact clause is what the argument turns on.  A
reference whose *only* semantic identity is a line number is malformed.

DEC-0040 section 7 recorded the failure this prevents: a two-line insertion
near the top of `docs/agents/product-orchestrator-agent.md` shifted every
subsequent line by +2 and silently invalidated every line-number citation into
that file across the landed corpus.  Most citations were rescued because they
carried a quotation.  Four were not, and became `UNRESOLVED - LOCATOR ONLY`.

WHAT THIS CHECKER ACTUALLY DOES - AND WHAT IT DOES NOT
------------------------------------------------------
It detects CITATION SHAPE.  Nothing more.

  * It CANNOT determine whether a reference is load-bearing.  It treats every
    citation on a governed surface as if it were.
  * It CANNOT semantically verify an anchor.  It sees that a section mark, a
    decision id or a quotation sits near the locator; it cannot check that the
    anchor names the clause the locator points at, nor that either resolves.
  * It CANNOT detect DRIFT.  Per D15 a drifted locator that still carries a
    durable anchor is a stale locator, NOT an authority defect, and must not
    fail.  This checker deliberately never opens the cited file.
  * It is therefore NOT semantic verification.  A green result proves only
    that no newly written reference has the malformed shape.

TWO RULES
---------
Rule 1 - LOCATOR-ENUMERATION (unconditional).
    Three or more line locators offered as one run, with nothing but
    separators (`,` `;` `and` `e`) between them.  A run by construction
    carries no interleaved anchor or quotation, and one nearby anchor cannot
    durably identify three distinct propositions - so no surrounding signal
    rescues it.  This is the exact shape of both debts DEC-0040 section 7
    escalated: `lines 40, 128, 152-167, 384, 790` and `:562, :563 and :565`.

Rule 2 - BARE-LOCATOR (windowed).
    One or two locators with no durability signal - no verbatim quotation, no
    section anchor, no `D<n>` decision id, no `item #n` / `row n` / `Annex X`
    anchor - anywhere within DURABILITY_WINDOW_CHARS of the run.

SCOPE
-----
Governed surfaces only (GOVERNED_PREFIXES / GOVERNED_FILES): the
INTERNAL-NORMATIVE decision corpus and the routing surfaces an operator
establishes authority from.  Source-code line citations (`opportunity.py:79`,
144 of the corpus's 177 locator tokens) are a different genre - they cite
executable code by position for audit reproduction, not an authority
proposition - and are OUT OF SCOPE.

In `check` mode only ADDED or MODIFIED lines are evaluated.  D15 "creates no
general citation framework" and imposes no retroactive obligation: no existing
line is judged, and no baseline-exception list exists or may be added.

`audit` mode evaluates every line of the governed surfaces.  It is a reporting
tool for a maintainer, never a gate.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

# --------------------------------------------------------------------------
# Tunables.  Each is a deliberate, documented choice, and boundary-tested.
# --------------------------------------------------------------------------

#: Characters scanned either side of a locator run for a durability signal.
#: 240 is about one clause/sentence in this corpus, where a whole paragraph is
#: written on a single physical line.  Wider would rescue almost everything;
#: narrower would flag ordinary, well-anchored prose.
DURABILITY_WINDOW_CHARS = 240

#: Shortest run of quoted characters accepted as a verbatim quotation.  Below
#: this a quoted fragment is a scare-quoted word, not a clause.
MIN_QUOTATION_CHARS = 12

#: Locators in one run at or above which Rule 1 fires unconditionally.
#: 2 is deliberately NOT enough: an adjacent pair (`:600-:601`, `:22 and :109`)
#: is routinely one proposition that a single anchor can carry.
ENUMERATION_THRESHOLD = 3

GOVERNED_PREFIXES = (
    "docs/product/decisions/",
    "docs/result/",
)
GOVERNED_FILES = (
    "docs/product/context-map.md",
    "docs/product/current-state.md",
    "docs/product/task-context-pack.md",
)

# --------------------------------------------------------------------------
# Grammar
# --------------------------------------------------------------------------

_EXT = r"(?:md|markdown|ts|tsx|js|mjs|cjs|py|yml|yaml|sql|json|toml|sh|ps1|txt)"
PATH_TOKEN_RE = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.@/-]*\." + _EXT + r"\b")

_NUM = r"\d{1,6}"
_RANGE_TAIL = r"(?:\s*[-–—]\s*:?" + _NUM + r")?"
COLON_ITEM_RE = re.compile(r":" + _NUM + _RANGE_TAIL)
BARE_ITEM_RE = re.compile(_NUM + _RANGE_TAIL)
SEPARATOR_RE = re.compile(r"(?:\s*,\s*(?:and\s+|e\s+)?|\s+(?:and|e)\s+|\s*;\s*)")
LINE_KEYWORD_RE = re.compile(r"\b(?:lines?|linhas?)\s+", re.IGNORECASE)

_Q = str(MIN_QUOTATION_CHARS)
QUOTATION_RE = re.compile(
    '"[^"]{' + _Q + ',}"'
    "|“[^”]{" + _Q + ",}”"
)
SECTION_ANCHOR_RE = re.compile(r"§\s*\*{0,2}[^\s*]")
DECISION_ID_RE = re.compile(r"\bD\d{1,2}\b")
ITEM_ANCHOR_RE = re.compile(
    r"\bitems?\s+\*{0,2}#?\d"
    r"|\britens?\s+\*{0,2}#?\d"
    r"|\brows?\s+\*{0,2}\d"
    r"|\bAnnex\s+[A-Z]\b"
    r"|\bAnexo\s+[A-Z]\b",
    re.IGNORECASE,
)

#: Signals sought inside the window itself.  QUOTATION is handled separately,
#: against spans matched over the WHOLE line: this corpus quotes clauses long
#: enough that a window centred on the locator can contain the closing
#: delimiter and not the opening one, which would otherwise read as "no
#: quotation" for a reference that is in fact fully quoted.
NON_QUOTE_SIGNALS = (
    ("SECTION-ANCHOR", SECTION_ANCHOR_RE),
    ("DECISION-ID", DECISION_ID_RE),
    ("ITEM-ANCHOR", ITEM_ANCHOR_RE),
)
SIGNAL_NAMES = ("QUOTATION",) + tuple(name for name, _ in NON_QUOTE_SIGNALS)

KIND_ENUMERATION = "LOCATOR-ENUMERATION"
KIND_BARE = "BARE-LOCATOR"

#: Stand-in for a keyword-form run whose file is named on an earlier line.
UNNAMED_PATH = "<file named outside this line>"


@dataclass(frozen=True)
class LocatorRun:
    """One run of line locators offered as a single reference."""

    start: int
    end: int
    items: tuple
    form: str  # "colon" | "keyword"
    cited_path: str

    @property
    def count(self) -> int:
        return len(self.items)


@dataclass(frozen=True)
class Finding:
    path: str
    line_no: int
    column: int
    kind: str
    cited_path: str
    snippet: str
    message: str

    def render(self) -> str:
        return f"{self.path}:{self.line_no}:{self.column}: {self.kind}: {self.message}"


def is_governed(path: str) -> bool:
    """True where DEC-0041 puts this file inside Limb B's scope."""
    p = path.replace("\\", "/")
    if not p.endswith(".md"):
        return False
    if p in GOVERNED_FILES:
        return True
    return any(p.startswith(prefix) for prefix in GOVERNED_PREFIXES)


def find_locator_runs(text):
    """Every locator run on one line that is associated with a file path.

    A run is a maximal sequence of locator items joined only by separators.
    Anything else between two numbers - a quotation, a parenthetical, an
    anchor - breaks the run, which is precisely the behaviour Rule 1 wants.

    Two forms, with deliberately different path requirements:

      * KEYWORD form (`lines 40, 128, 384 and 790`).  The word `line(s)` is
        itself unambiguous evidence that the numbers are line locators, so no
        path token is required on the same line.  This matters: DEC-0036 D2's
        escalated enumeration names its file in the *preceding* paragraph.
      * COLON form (`:565`).  A path token must appear earlier on the line.
        Without one there is nothing for the locator to be a locator *into*.

        STATED PRECISELY, BECAUSE THE WEAKER CLAIM IS THE TRUE ONE: this
        requirement removes the NO-PATH class only.  It does NOT make the
        colon form safe against clock times, ratios, versions or any other
        colon-number.  On a line that happens to name a file - which is most
        lines on a governed surface - `postgres:15`, `09:45`, `4:0` and `3:1`
        ARE read as locator runs and ARE flagged.  The guard buys exactly
        one thing, and it is narrower than it sounds: a COLON-FORM candidate
        on a line carrying no earlier path token is never scanned.

        It bounds the colon form alone.  KEYWORD-form references stay
        eligible with no same-line path token at all - by design, and that is
        exactly how DEC-0036 D2's `lines 40, 128, 384 and 790` is caught.

        This is a KNOWN FALSE-POSITIVE CLASS, disclosed at DEC-0041 section
        13 and pinned by TestFalsePositiveGuards, not a defect to be silently
        widened away.  Narrowing it would mean changing detection semantics,
        which is a separate authorized decision - not a docstring edit.

    MENTION versus USE.  A locator run lying entirely inside a verbatim
    quotation is being *quoted*, not *made* - DEC-0040 section 7 quotes
    DEC-0036's malformed enumeration in order to report it.  Such runs are
    skipped, because the alternative is to pressure an author into altering
    quoted historical text, which the corpus forbids outright.
    """
    paths = list(PATH_TOKEN_RE.finditer(text))
    quoted_spans = [(m.start(), m.end()) for m in QUOTATION_RE.finditer(text)]

    candidates = []
    for m in LINE_KEYWORD_RE.finditer(text):
        candidates.append((m.start(), "keyword", m))
    for m in COLON_ITEM_RE.finditer(text):
        candidates.append((m.start(), "colon", m))
    candidates.sort(key=lambda c: (c[0], c[1]))

    runs = []
    consumed_to = -1
    for start, form, m in candidates:
        if start < consumed_to:
            continue
        if form == "keyword":
            item_re = BARE_ITEM_RE
            first = item_re.match(text, m.end())
            if first is None:
                continue
        else:
            item_re = COLON_ITEM_RE
            first = m
        run_start = m.start()

        preceding = [p for p in paths if p.end() <= run_start]
        if preceding:
            cited_path = preceding[-1].group(0)
        elif form == "keyword":
            cited_path = UNNAMED_PATH
        else:
            continue

        items = [(first.start(), first.end())]
        cursor = first.end()
        while True:
            sep = SEPARATOR_RE.match(text, cursor)
            if sep is None:
                break
            nxt = item_re.match(text, sep.end())
            if nxt is None:
                break
            items.append((nxt.start(), nxt.end()))
            cursor = nxt.end()

        consumed_to = cursor
        if any(lo <= run_start and cursor <= hi for lo, hi in quoted_spans):
            continue  # quoted, therefore mentioned rather than made
        runs.append(
            LocatorRun(
                start=run_start,
                end=cursor,
                items=tuple(items),
                form=form,
                cited_path=cited_path,
            )
        )
    return runs


def durability_signals(text, run, quoted_spans=None):
    """Names of every durability signal found in the run's window."""
    lo = max(0, run.start - DURABILITY_WINDOW_CHARS)
    hi = min(len(text), run.end + DURABILITY_WINDOW_CHARS)
    window = text[lo:hi]
    if quoted_spans is None:
        quoted_spans = [(m.start(), m.end()) for m in QUOTATION_RE.finditer(text)]
    found = []
    if any(qs < hi and qe > lo for qs, qe in quoted_spans):
        found.append("QUOTATION")
    found.extend(name for name, rx in NON_QUOTE_SIGNALS if rx.search(window))
    return found


def evaluate_line(path, line_no, text):
    findings = []
    for run in find_locator_runs(text):
        snippet = text[run.start:run.end].strip()
        if run.count >= ENUMERATION_THRESHOLD:
            findings.append(
                Finding(
                    path=path,
                    line_no=line_no,
                    column=run.start + 1,
                    kind=KIND_ENUMERATION,
                    cited_path=run.cited_path,
                    snippet=snippet,
                    message=(
                        "%d line locators are offered as the identity of `%s` (%r) "
                        "with nothing but separators between them. One anchor cannot "
                        "identify %d distinct propositions. Cite each proposition by "
                        "named section/clause anchor, with a short verbatim quotation "
                        "where it is load-bearing (DEC-0040 D15)."
                        % (run.count, run.cited_path, snippet, run.count)
                    ),
                )
            )
            continue
        if not durability_signals(text, run):
            findings.append(
                Finding(
                    path=path,
                    line_no=line_no,
                    column=run.start + 1,
                    kind=KIND_BARE,
                    cited_path=run.cited_path,
                    snippet=snippet,
                    message=(
                        "the line locator %r is the sole semantic identity of this "
                        "reference to `%s`: no verbatim quotation, no section anchor, "
                        "no decision id and no item/row anchor within %d characters. "
                        "LINE NUMBER = LOCATOR / CONVENIENCE ONLY (DEC-0040 D15)."
                        % (snippet, run.cited_path, DURABILITY_WINDOW_CHARS)
                    ),
                )
            )
    return findings


def evaluate_text(path, text):
    findings = []
    for i, line in enumerate(text.splitlines(), start=1):
        findings.extend(evaluate_line(path, i, line))
    return findings


# --------------------------------------------------------------------------
# Unified-diff parsing (pure; no git invocation here, so it stays testable)
# --------------------------------------------------------------------------

_HUNK_RE = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@")


def added_lines_from_diff(diff_text):
    """Map path -> [(new line number, text)] for every added line in a diff.

    Expects `git diff --unified=0`.  A modified line appears as a `-` plus a
    `+`, so "changed" lines are covered by reading the `+` side.
    """
    result = {}
    current = None
    next_no = 0
    for raw in diff_text.splitlines():
        if raw.startswith("+++ "):
            target = raw[4:].strip()
            if target == "/dev/null":
                current = None
            else:
                current = target[2:] if target.startswith(("a/", "b/")) else target
            continue
        if raw.startswith("--- ") or raw.startswith("diff --git "):
            continue
        m = _HUNK_RE.match(raw)
        if m:
            next_no = int(m.group(1))
            continue
        if current is None:
            continue
        if raw.startswith("+"):
            result.setdefault(current, []).append((next_no, raw[1:]))
            next_no += 1
        elif raw.startswith(" "):
            next_no += 1
    return result


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------


def _git_diff(base, repo_root):
    proc = subprocess.run(
        ["git", "diff", "--unified=0", "--no-color", "%s...HEAD" % base],
        cwd=str(repo_root),
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return proc.stdout


def _governed_files(repo_root):
    out = []
    for prefix in GOVERNED_PREFIXES:
        base = repo_root / prefix
        if base.is_dir():
            out.extend(
                str(p.relative_to(repo_root)).replace("\\", "/")
                for p in sorted(base.rglob("*.md"))
            )
    for name in GOVERNED_FILES:
        if (repo_root / name).is_file():
            out.append(name)
    return sorted(set(out))


def _report(findings, stream):
    for f in findings:
        print(f.render(), file=stream)


def main(argv=None):
    ap = argparse.ArgumentParser(
        prog="check_reference_durability",
        description="DEC-0040 D15 reference-durability check (citation shape only).",
    )
    ap.add_argument("mode", choices=("check", "audit"))
    ap.add_argument(
        "--base", help="check mode: git ref to diff against (merge-base is used)."
    )
    ap.add_argument(
        "--diff-file",
        help="check mode: read a unified diff from this path, or '-' for stdin, "
        "instead of invoking git.",
    )
    ap.add_argument("--repo-root", default=".", help="repository root (default: .)")
    ap.add_argument(
        "--strict",
        action="store_true",
        help="audit mode: exit non-zero when findings exist.",
    )
    args = ap.parse_args(argv)
    repo_root = Path(args.repo_root).resolve()

    if args.mode == "check":
        if args.diff_file:
            if args.diff_file == "-":
                diff_text = sys.stdin.read()
            else:
                diff_text = Path(args.diff_file).read_text(encoding="utf-8")
        elif args.base:
            diff_text = _git_diff(args.base, repo_root)
        else:
            ap.error("check mode requires --base or --diff-file")
        added = added_lines_from_diff(diff_text)
        findings = []
        scanned = 0
        for path, lines in sorted(added.items()):
            if not is_governed(path):
                continue
            scanned += len(lines)
            for line_no, text in lines:
                findings.extend(evaluate_line(path, line_no, text))
        print(
            "reference-durability: prospective check over %d added/changed line(s) "
            "on governed surfaces." % scanned
        )
        if findings:
            _report(findings, sys.stdout)
            print(
                "::error::reference-durability: %d malformed reference(s). "
                "See DEC-0040 D15 and DEC-0041." % len(findings)
            )
            return 1
        print("reference-durability: OK - no malformed reference shape introduced.")
        return 0

    files = _governed_files(repo_root)
    findings = []
    for rel in files:
        text = (repo_root / rel).read_text(encoding="utf-8")
        findings.extend(evaluate_text(rel, text))
    print("reference-durability AUDIT: %d governed file(s) scanned." % len(files))
    _report(findings, sys.stdout)
    print("reference-durability AUDIT: %d finding(s)." % len(findings))
    return 1 if (findings and args.strict) else 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
