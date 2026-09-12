"""Text/size contract checks and MOTD previews, not a Pawn/client emulator."""
import argparse
import html
from pathlib import Path
import re
import unittest

SOURCE = Path(__file__).with_name("ultrahc_help.sma").read_text(encoding="utf-8")
STRING = r'"(?:\^.|[^"^])*"'


def decode(value):
    escapes = {"n": "\n", "r": "\r", "t": "\t", '"': '"', "^": "^"}
    return re.sub(r"\^(.)", lambda m: escapes.get(m[1], m[1]), value[1:-1])


def constant(name):
    return decode(re.search(r"new const " + name + r"\[\] = (" + STRING + r");", SOURCE)[1])


HEAD, END = constant("MOTD_HEAD"), constant("MOTD_END")
BODY_LIMIT = int(re.search(r"#define MOTD_BODY_BYTES (\d+)", SOURCE)[1])
MOTD_LIMIT = int(re.search(r"#define MOTD_BYTES (\d+)", SOURCE)[1])
CATALOG = []
for match in re.finditer(r"\bAdd\((\d+), (" + STRING + r"), (" + STRING + r")(.*?)\);", SOURCE):
    tail = re.findall(STRING, match[4])
    CATALOG.append({"section": int(match[1]), "title": decode(match[2]),
                    "description": decode(match[3]), "command": decode(tail[0]) if tail else ""})
block = re.search(r"new const direct\[\]\[\] = \{(.*?)\};", SOURCE, re.S)[1]
DIRECT = {decode(s) for s in re.findall(STRING, block)}


def pages_for(entries):
    pages, current, size = [], [], 0
    raw = "".join(e["title"] + "\n" + e["description"] + "\n\n" for e in entries)
    for char in raw:
        token = html.escape(char, quote=False)
        length = len(token.encode("utf-8"))
        if size + length > BODY_LIMIT:
            pages.append("".join(current))
            current, size = [], 0
        current.append(token)
        size += length
    pages.append("".join(current))
    return raw, pages


class UIContract(unittest.TestCase):
    def assert_pages(self, entries):
        raw, pages = pages_for(entries)
        self.assertEqual("".join(html.unescape(p) for p in pages), raw)
        for page in pages:
            rendered = (HEAD + page + END).encode("utf-8")
            self.assertLessEqual(len(rendered), MOTD_LIMIT)
            self.assertLess(MOTD_LIMIT, 1536)
            rendered.decode("utf-8", errors="strict")
            self.assertNotRegex(page, r"[<>]")
        return pages

    def test_player_and_admin_catalog(self):
        self.assertGreaterEqual(len(CATALOG), 36)
        public = self.assert_pages([e for e in CATALOG if e["section"] in (1, 2)])
        admin = self.assert_pages(CATALOG)
        self.assertGreater(len(admin), len(public))
        self.assertNotIn("uhc_blockdmg_set", "".join(public))
        self.assertIn("uhc_blockdmg_set", "".join(admin))

    def test_max_rules_and_unicode_are_not_lost(self):
        rules = [{"title": f"Правило {i}", "description": "<&>" * 106 + "!!"} for i in range(1, 65)]
        self.assert_pages(CATALOG + rules)
        self.assert_pages([{"title": "Русский текст", "description": "Я🙂<&>" * 500}])

    def test_empty_and_html_like_text(self):
        self.assertEqual(self.assert_pages([]), [""])
        self.assert_pages([{"title": "<script>", "description": "&lt;img&gt;\n100%"}])

    def test_action_menu_byte_limit(self):
        for section, heading in ((1, "Команды игрока"), (3, "Команды администратора")):
            entries = [e for e in CATALOG if e["section"] == section and (
                e["command"] in DIRECT or e["title"] == "Урон: начать голосование"
                or e["command"] in ("uhc_blockdmg_set", "uhc_blockdmg_rem"))]
            count = max(1, (len(entries) + 4) // 5)
            for page in range(count):
                menu = f"\\y{heading} ({page + 1}/{count})\\w\n\n"
                menu += "".join(f"{i + 1}. {e['title']}\n" for i, e in enumerate(entries[page * 5:page * 5 + 5]))
                if page > 0:
                    menu += "\n6. Предыдущая страница"
                if page + 1 < count:
                    menu += "\n7. Следующая страница"
                menu += "\n8. В начало\n9. Справка\n0. Закрыть"
                self.assertLessEqual(len(menu.encode("utf-8")), 511)

    def test_direct_actions_have_no_missing_arguments(self):
        for command in ("slcreate", "+place_ad", "uhc_blockdmg_set", "uhc_blockdmg_rem", "uhc_blockdmg_vote"):
            self.assertNotIn(command, DIRECT)
        self.assertTrue(DIRECT.issubset({e["command"] for e in CATALOG}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview-dir", type=Path)
    args = parser.parse_args()
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(UIContract))
    if not result.wasSuccessful():
        raise SystemExit(1)
    if args.preview_dir:
        args.preview_dir.mkdir(parents=True, exist_ok=False)
        for role, entries in (("player", [e for e in CATALOG if e["section"] in (1, 2)]), ("admin", CATALOG)):
            _, pages = pages_for(entries)
            for index, page in enumerate(pages, 1):
                (args.preview_dir / f"{role}-{index:02}.html").write_text(HEAD + page + END, encoding="utf-8")
            print(f"{role}: {len(pages)} pages, max {max(len((HEAD + p + END).encode('utf-8')) for p in pages)} bytes")
