"""Tests for the DEC-0040 D15 reference-durability check.

Stdlib-only `unittest`, matching the repository idiom
(`.github/workflows/data-engine-tests.yml`).

These tests validate C5's own implementation only.  They create no
repository-wide testing policy - that is Phase D.

They deliberately assert BOTH halves of the contract:

  * what the control DOES detect (TestMalformedShapes, TestEnumerationRule),
  * what it DOES NOT detect (TestHonestLimits), so that a green result is
    never read as more than it is.
"""

import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import check_reference_durability as rd  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parents[3]

PO = "`docs/agents/product-orchestrator-agent.md`"


def kinds(text, path="docs/product/decisions/DEC-9999-x.md", line_no=1):
    return [f.kind for f in rd.evaluate_line(path, line_no, text)]


class TestMalformedShapes(unittest.TestCase):
    """Rule 2 - a line locator used as the sole semantic identity."""

    def test_the_writ_must_fail_case(self):
        # The exact shape DEC-0040 §7 escalated: path + bare number, no
        # named clause, no quotation, no anchor.
        self.assertEqual(
            kinds("See `product-orchestrator-agent.md`:565 for the rule."),
            [rd.KIND_BARE],
        )

    def test_bare_locator_in_a_terse_bullet(self):
        self.assertEqual(kinds("- `product-orchestrator-agent.md`:399"), [rd.KIND_BARE])

    def test_two_bare_locators_still_flag(self):
        # Below the enumeration threshold, so Rule 2 (not Rule 1) applies.
        self.assertEqual(kinds("- `agent-boundaries.md`:202 and :208"), [rd.KIND_BARE])

    def test_range_locator_is_one_item_and_still_flags(self):
        self.assertEqual(kinds("- `agent-boundaries.md`:338-347"), [rd.KIND_BARE])


class TestDurableShapesPass(unittest.TestCase):
    """Rule 2 - anything carrying a durability signal is left alone."""

    def test_named_section_anchor(self):
        self.assertEqual(
            kinds(PO + " §*Regras de atribuicao*, the exception clause (`:567`)."), []
        )

    def test_verbatim_quotation(self):
        self.assertEqual(
            kinds(PO + ':567 requires that "qualquer excecao a separacao de '
                  'funcoes requer decisao explicita do Product Lead".'),
            [],
        )

    def test_curly_quotation(self):
        self.assertEqual(
            kinds(PO + ":567 requires that “qualquer excecao a separacao"
                  " de funcoes”."),
            [],
        )

    def test_decision_id_anchor(self):
        self.assertEqual(kinds("`DEC-0040` D15 applies to `agent.md`:565."), [])

    def test_item_anchor(self):
        self.assertEqual(
            kinds("`agent-review-matrix.md`:44 - item #12, the mandatory reviewer."),
            [],
        )

    def test_annex_anchor(self):
        self.assertEqual(kinds("`DEC-0035` Annex A row 12 at `dec-0035.md`:241."), [])

    def test_long_quotation_whose_opening_is_outside_the_window(self):
        # Regression: a clause long enough that a window centred on the
        # locator sees only the closing delimiter.  Quotation spans are
        # matched over the whole line for exactly this reason.
        quote = '"' + ("palavra " * 60).strip() + '"'
        self.assertEqual(kinds("`agent.md` diz " + quote + " (`:601`)."), [])


class TestEnumerationRule(unittest.TestCase):
    """Rule 1 - N locators offered as identity, separators only between them."""

    def test_three_is_the_threshold(self):
        self.assertEqual(rd.ENUMERATION_THRESHOLD, 3)
        self.assertEqual(kinds(PO + " - specifically :562, :563 and :565."),
                         [rd.KIND_ENUMERATION])

    def test_two_is_below_the_threshold(self):
        # Boundary: an adjacent pair is routinely one proposition.  With an
        # anchor present it passes; Rule 1 must not fire on it at all.
        self.assertEqual(kinds(PO + " §*Stage-Gate Discipline* :600 and :601."), [])

    def test_enumeration_is_unconditional_and_no_anchor_rescues_it(self):
        # A section anchor AND a quotation sit right beside the run; the run
        # still fails, because one anchor cannot identify three propositions.
        text = (PO + ' §*Regras de atribuicao* - "uma citacao bem longa aqui" '
                "- specifically :562, :563 and :565.")
        self.assertEqual(kinds(text), [rd.KIND_ENUMERATION])

    def test_keyword_form_needs_no_path_on_the_same_line(self):
        # DEC-0036 D2's shape: the file is named in the preceding paragraph.
        self.assertEqual(
            kinds("The contract uses the same idiom at lines 40, 128, 384 and 790."),
            [rd.KIND_ENUMERATION],
        )

    def test_interleaved_quotations_break_the_run(self):
        # The remedy the message prescribes must actually pass.  Each locator
        # now carries its own quotation, so there is no enumeration left.
        text = (
            PO + ' §*Regras de atribuicao*: :564 ("o reviewer de um artefato nao '
            'deve ser o Author"), :565 ("o governance reviewer nao deve ser o '
            'executor"), :567 ("qualquer excecao requer decisao do Product Lead").'
        )
        self.assertEqual(kinds(text), [])


class TestMentionVersusUse(unittest.TestCase):
    def test_a_quoted_citation_is_mentioned_not_made(self):
        # DEC-0040 §7 quotes DEC-0036's malformed enumeration in order to
        # report it.  Flagging that would pressure an author into altering
        # quoted historical text.
        self.assertEqual(
            kinds('D2 cites "lines 40, 128, 384 and 790" as the same idiom.'), []
        )

    def test_an_unquoted_enumeration_beside_a_quotation_still_fails(self):
        self.assertEqual(
            kinds('D2 cites "the same recurring idiom" at lines 40, 128, 384 and 790.'),
            [rd.KIND_ENUMERATION],
        )


class TestFalsePositiveGuards(unittest.TestCase):
    def test_a_colon_number_without_any_path_is_not_a_citation(self):
        self.assertEqual(kinds("The run started at 14:30 and ended at 16:45."), [])

    def test_a_number_of_lines_is_not_a_line_number(self):
        self.assertEqual(kinds("The file is 859 lines at this base."), [])

    def test_prose_without_locators_is_clean(self):
        self.assertEqual(kinds("`DEC-0037` D5 fixes `AUTHOR != REVIEWER`."), [])

    def test_the_no_path_guard_removes_only_the_no_path_class(self):
        """The path-token requirement is far weaker than it reads.

        It buys exactly one thing, and only for the COLON form: a colon-form
        candidate on a line with no earlier path token is never scanned.  It
        does NOT make the colon form safe against clock times, ratios or
        versions.  On a line that names a file - which is most lines on a
        governed surface - every one of these IS flagged.  Keyword-form
        references are not bounded by it at all and stay eligible with no
        same-line path token.

        Asserted as ACTUAL BEHAVIOUR, not as desired behaviour.  This pins a
        disclosed false-positive class (DEC-0041 §13) so that it cannot be
        described as excluded, and so that any future change to detection
        semantics has to break this test deliberately rather than quietly.
        """
        flagged = {
            "version": "`docs/product/current-state.md` pins the local stack "
                       "to postgres:15 for parity.",
            "clock": "Per `docs/result/PHASE-B-CLOSEOUT-R1.md` the run started "
                     "09:45 and ended 11:20.",
            "tally": "In `docs/agents/agent-review-matrix.md` the vote was 4:0 "
                     "in favour.",
            "ratio": "See `docs/product/context-map.md` for the 3:1 ratio and "
                     "the 2:1 fallback.",
        }
        for name, text in flagged.items():
            with self.subTest(name):
                self.assertEqual(
                    set(kinds(text)), {rd.KIND_BARE},
                    "%s: expected the disclosed false positive, not silence" % name,
                )

        # The exact counts, so the class is measured rather than gestured at.
        self.assertEqual(len(kinds(flagged["clock"])), 2)   # :45 and :20
        self.assertEqual(len(kinds(flagged["ratio"])), 2)   # :1 and :1
        self.assertEqual(len(kinds(flagged["version"])), 1)  # :15
        self.assertEqual(len(kinds(flagged["tally"])), 1)    # :0

        # The one case the guard genuinely does remove: a COLON-FORM
        # candidate with no earlier path token on its line.
        self.assertEqual(kinds("The run started at 14:30 and finished 16:05."), [])


class TestHonestLimits(unittest.TestCase):
    """What this control does NOT do.  These tests exist to prevent the
    checker from being described as more than it is."""

    def test_it_does_not_detect_drift(self):
        # A well-anchored citation whose number is simply WRONG passes.  Per
        # D15 a drifted locator is a stale locator, not an authority defect,
        # and must not fail.  The checker never opens the cited file.
        self.assertEqual(
            kinds(PO + ' §*Source of Truth*: "Os documentos em /context sao a '
                  'fonte da verdade" (`:999999`).'),
            [],
        )

    def test_it_does_not_verify_that_the_anchor_matches_the_locator(self):
        # The section named here has nothing to do with the clause cited.
        # A regex cannot tell.  This is shape detection, not semantics.
        self.assertEqual(kinds(PO + " §*Completely Unrelated Section* :565."), [])

    def test_it_cannot_judge_load_bearingness(self):
        # A throwaway aside is treated exactly like a load-bearing citation.
        self.assertEqual(
            kinds("Incidentally, see `agent.md`:12 sometime."), [rd.KIND_BARE]
        )

    def test_a_meaningless_anchor_token_is_accepted(self):
        # `D5` is accepted as a decision id wherever it appears in the window.
        self.assertEqual(kinds("Model D5 of the printer, see `agent.md`:565."), [])


class TestGovernedScope(unittest.TestCase):
    def test_governed_surfaces(self):
        for p in (
            "docs/product/decisions/DEC-0041-mechanical-governance-enforcement.md",
            "docs/product/context-map.md",
            "docs/product/current-state.md",
            "docs/product/task-context-pack.md",
            "docs/result/PHASE-B-CLOSEOUT-R1.md",
        ):
            self.assertTrue(rd.is_governed(p), p)

    def test_ungoverned_surfaces(self):
        for p in (
            # Agent contracts are cited INTO, not citing; also outside C5's
            # write scope.
            "docs/agents/product-orchestrator-agent.md",
            # Source-code citation genre - 144 of the corpus's 177 locator
            # tokens live here and are deliberately out of scope.
            "docs/data/DATA-AUDIT-001-determinism-conformance.md",
            "context/01_MVP_Scope_PRD.md",
            "services/data-engine/src/noxund_data_engine/scoring.py",
            "docs/product/decisions/DEC-0041.txt",
        ):
            self.assertFalse(rd.is_governed(p), p)

    def test_windows_separators_are_normalised(self):
        self.assertTrue(rd.is_governed(r"docs\product\decisions\DEC-0041-x.md"))


class TestDiffParsing(unittest.TestCase):
    DIFF = (
        "diff --git a/docs/product/context-map.md b/docs/product/context-map.md\n"
        "--- a/docs/product/context-map.md\n"
        "+++ b/docs/product/context-map.md\n"
        "@@ -10,0 +11,2 @@\n"
        "+first added line\n"
        "+second added line\n"
        "@@ -40,1 +42,1 @@\n"
        "-old text\n"
        "+new text\n"
        "diff --git a/README.md b/README.md\n"
        "--- a/README.md\n"
        "+++ b/README.md\n"
        "@@ -1,0 +2,1 @@\n"
        "+untouched by scope\n"
    )

    def test_added_line_numbers(self):
        added = rd.added_lines_from_diff(self.DIFF)
        self.assertEqual(
            added["docs/product/context-map.md"],
            [(11, "first added line"), (12, "second added line"), (42, "new text")],
        )
        self.assertIn("README.md", added)

    def test_deleted_file_is_ignored(self):
        diff = (
            "diff --git a/x.md b/x.md\n--- a/x.md\n+++ /dev/null\n"
            "@@ -1,1 +0,0 @@\n-gone\n"
        )
        self.assertEqual(rd.added_lines_from_diff(diff), {})

    def test_check_mode_only_evaluates_governed_added_lines(self):
        diff = (
            "diff --git a/docs/agents/x.md b/docs/agents/x.md\n"
            "--- a/docs/agents/x.md\n+++ b/docs/agents/x.md\n@@ -0,0 +1,1 @@\n"
            "+see `agent.md`:565 for the rule\n"
            "diff --git a/docs/product/decisions/DEC-0099-y.md "
            "b/docs/product/decisions/DEC-0099-y.md\n"
            "--- a/docs/product/decisions/DEC-0099-y.md\n"
            "+++ b/docs/product/decisions/DEC-0099-y.md\n@@ -0,0 +1,1 @@\n"
            "+see `agent.md`:565 for the rule\n"
        )
        added = rd.added_lines_from_diff(diff)
        governed = [p for p in added if rd.is_governed(p)]
        self.assertEqual(governed, ["docs/product/decisions/DEC-0099-y.md"])
        findings = rd.evaluate_line(governed[0], 1, added[governed[0]][0][1])
        self.assertEqual([f.kind for f in findings], [rd.KIND_BARE])


class TestCurrentCorpus(unittest.TestCase):
    """Baseline facts about the repository as it stands.

    Asserted semantically rather than as a golden count: a corpus edit may
    legitimately move the total, and a count assertion would only invite
    baselining, which this control has no mechanism for and must not grow.
    """

    @classmethod
    def setUpClass(cls):
        cls.findings = []
        for rel in rd._governed_files(REPO_ROOT):
            text = (REPO_ROOT / rel).read_text(encoding="utf-8")
            cls.findings.extend(rd.evaluate_text(rel, text))

    def _kinds_for(self, needle):
        return {f.kind for f in self.findings if needle in f.path}

    def test_it_detects_the_dec_0036_escalated_enumerations(self):
        self.assertIn(rd.KIND_ENUMERATION, self._kinds_for("DEC-0036"))

    def test_it_detects_the_dec_0037_escalated_enumeration(self):
        self.assertIn(rd.KIND_ENUMERATION, self._kinds_for("DEC-0037"))

    def test_the_corpus_baseline_is_small_enough_that_no_cleanup_is_implied(self):
        # C5 is not historical normalisation.  If this ever grew large, the
        # right response is to NARROW the prospective scope, never to add
        # exceptions.
        self.assertLess(len(self.findings), 30, "\n".join(
            f.render() for f in self.findings))

    def test_the_limb_a_forward_notes_pass_on_their_merits(self):
        # They are not exempted anywhere; they carry anchors and quotations.
        for rel in (
            "docs/product/decisions/"
            "DEC-0036-scope-guardrails-authority-class-descriptive-current.md",
            "docs/product/decisions/"
            "DEC-0037-execution-topology-role-independence-governance-review-function.md",
        ):
            lines = (REPO_ROOT / rel).read_text(encoding="utf-8").split("\n")
            start = next(
                i for i, line in enumerate(lines, 1)
                if line.startswith("## Additive forward-status note")
            )
            note = [
                f
                for n in range(start, len(lines) + 1)
                for f in rd.evaluate_line(rel, n, lines[n - 1])
            ]
            self.assertEqual(note, [], rel)

    def test_dec_0041_introduces_no_malformed_reference(self):
        matches = sorted(
            (REPO_ROOT / "docs/product/decisions").glob("DEC-0041-*.md")
        )
        self.assertEqual(len(matches), 1, "expected exactly one DEC-0041 file")
        rel = "docs/product/decisions/" + matches[0].name
        found = rd.evaluate_text(rel, matches[0].read_text(encoding="utf-8"))
        self.assertEqual(found, [], "\n".join(f.render() for f in found))


class TestCli(unittest.TestCase):
    SCRIPT = str(Path(rd.__file__))

    def _run(self, *args, stdin=""):
        return subprocess.run(
            [sys.executable, self.SCRIPT, *args],
            input=stdin, capture_output=True, text=True, cwd=str(REPO_ROOT),
        )

    def test_check_mode_exits_zero_on_a_clean_diff(self):
        diff = (
            "diff --git a/docs/product/decisions/DEC-0099-y.md "
            "b/docs/product/decisions/DEC-0099-y.md\n"
            "--- a/docs/product/decisions/DEC-0099-y.md\n"
            "+++ b/docs/product/decisions/DEC-0099-y.md\n@@ -0,0 +1,1 @@\n"
            "+`agent.md` §*Regras*: \"uma citacao literal longa\" (`:567`).\n"
        )
        proc = self._run("check", "--diff-file", "-", stdin=diff)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("OK", proc.stdout)

    def test_check_mode_exits_non_zero_on_a_malformed_addition(self):
        diff = (
            "diff --git a/docs/product/decisions/DEC-0099-y.md "
            "b/docs/product/decisions/DEC-0099-y.md\n"
            "--- a/docs/product/decisions/DEC-0099-y.md\n"
            "+++ b/docs/product/decisions/DEC-0099-y.md\n@@ -0,0 +1,1 @@\n"
            "+see `product-orchestrator-agent.md`:565 for the rule\n"
        )
        proc = self._run("check", "--diff-file", "-", stdin=diff)
        self.assertEqual(proc.returncode, 1, proc.stdout + proc.stderr)
        self.assertIn(rd.KIND_BARE, proc.stdout)

    def test_audit_mode_reports_without_gating(self):
        proc = self._run("audit", "--repo-root", str(REPO_ROOT))
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("AUDIT", proc.stdout)


if __name__ == "__main__":
    unittest.main()
