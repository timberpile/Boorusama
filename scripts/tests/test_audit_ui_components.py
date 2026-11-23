"""Tests for the conservative Kurumi/Material source-level inventory."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "audit_ui_components.py"
SPEC = importlib.util.spec_from_file_location("audit_ui_components", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)


class LexerTests(unittest.TestCase):
    def test_comments_strings_nested_blocks_and_raw_literals_are_ignored(self):
        source = '''
/* Outer /* inner KurumiButton() */ PopupMenuItem() */
final a = "KurumiButton()";
final b = r'PopupMenuItem()';
final c = """TextField()\nKurumiTextField()""";
// AlertDialog()
final widget = KurumiButton(onPressed: () {});
'''
        clean = AUDIT.mask_dart_trivia(source)
        matches = [m.group("name") for m in AUDIT.CONSTRUCTOR_RE.finditer(clean)]
        self.assertEqual(["KurumiButton"], matches)
        self.assertEqual(source.count("\n"), clean.count("\n"))
        self.assertEqual(len(source), len(clean))

    def test_escaped_quotes_and_comment_markers_within_strings(self):
        source = '''
final a = 'escaped\\' and // not a comment';
final b = "/* also not a comment */";
KurumiSettingsCard(child: Text('okay'));
'''
        clean = AUDIT.mask_dart_trivia(source)
        self.assertEqual(
            ["KurumiSettingsCard"],
            [m.group("name") for m in AUDIT.CONSTRUCTOR_RE.finditer(clean)],
        )


class InventoryTests(unittest.TestCase):
    def test_scans_packages_and_app_and_reports_review_candidates(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            kurumi = root / "packages/kurumi/lib/src/components/button.dart"
            app = root / "lib/core/search/following_topics/src/pages/topics_page.dart"
            kurumi.parent.mkdir(parents=True)
            app.parent.mkdir(parents=True)
            kurumi.write_text(
                "class KurumiButton extends StatelessWidget {}\n"
                "class KurumiInput extends StatelessWidget {}\n",
                encoding="utf-8",
            )
            kurumi_factory = root / "packages/kurumi/lib/src/components/adaptive_button_row.dart"
            kurumi_factory.parent.mkdir(parents=True, exist_ok=True)
            kurumi_factory.write_text(
                "class KurumiAdaptiveButtonRow {\n"
                "  factory KurumiAdaptiveButtonRow.menu() => KurumiAdaptiveButtonRow();\n"
                "}\n",
                encoding="utf-8",
            )
            app.write_text(
                "// PopupMenuButton()\n"
                "KurumiButton(onPressed: () {});\n"
                "PopupMenuButton<String>(itemBuilder: (_) => []);\n"
                "Kurumi.showAdaptiveSheet(context, builder: (_) => null);\n"
                "const t = 'AlertDialog()';\n"
                "const KurumiInput();\n"
                "FilledButton.icon(onPressed: null, label: const Text('x'));\n"
                "FilledButton.styleFrom();\n"
                "Dialog.fullscreen();\n"
                "KurumiAdaptiveButtonRow.menu();\n"
                "Scaffold.maybeOf(context);\n",
                encoding="utf-8",
            )
            result = AUDIT.scan(root)
            self.assertEqual(3, len(result["files"]))
            self.assertEqual(
                {"KurumiButton", "KurumiInput", "KurumiAdaptiveButtonRow"},
                {x["symbol"] for x in result["definitions"]},
            )
            uses = {(x["symbol"], x["line"]) for x in result["usages"] if x["path"].startswith("lib/")}
            self.assertEqual(
                {("KurumiButton", 2), ("PopupMenuButton", 3),
                 ("Kurumi.showAdaptiveSheet", 4), ("KurumiInput", 6),
                 ("FilledButton", 7), ("Dialog", 9),
                 ("KurumiAdaptiveButtonRow", 10)}, uses
            )
            self.assertNotIn(("FilledButton", 8), uses)
            self.assertNotIn(("Scaffold", 11), uses)
            app_record = next(x for x in result["files"] if x["path"].startswith("lib/"))
            self.assertEqual("Following Topics", app_record["area"])
            self.assertEqual(4, app_record["kurumi_calls"])
            self.assertEqual(1, app_record["material_review_calls"])
            report = AUDIT.markdown_report(result)
            self.assertIn("Kurumi-named declarations defined in package", report)
            self.assertIn("Raw package usage records may include constructor declarations", report)
            self.assertIn("PopupMenuButton", report)
            self.assertNotIn("AlertDialog` | 1", report)

    def test_skips_generated_dart_sources(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            kurumi = root / "packages/kurumi/lib"
            app = root / "lib"
            kurumi.mkdir(parents=True)
            app.mkdir(parents=True)
            (kurumi / "normal.dart").write_text("class KurumiThing {}", encoding="utf-8")
            (app / "generated.g.dart").write_text("KurumiThing();", encoding="utf-8")
            generated_dir_file = app / "src/generated/generated_file.dart"
            generated_dir_file.parent.mkdir(parents=True)
            generated_dir_file.write_text("KurumiThing();", encoding="utf-8")
            (app / "visible.dart").write_text("KurumiThing();", encoding="utf-8")
            result = AUDIT.scan(root)
            self.assertEqual(2, len(result["files"]))
            self.assertEqual(
                {"packages/kurumi/lib/normal.dart", "lib/visible.dart"},
                {item["path"] for item in result["files"]},
            )


if __name__ == "__main__":
    unittest.main()
