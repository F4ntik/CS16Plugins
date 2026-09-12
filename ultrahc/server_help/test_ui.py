"""Source-based HTML/menu contract checks; not a Pawn or CS-client emulator."""
import argparse
import html
from html.parser import HTMLParser
import itertools
from pathlib import Path
import re
import unittest

SOURCE = Path(__file__).with_name("ultrahc_help.sma").read_text(encoding="utf-8")
STRING = r'"(?:\^.|[^"^])*"'
LIMIT = int(re.search(r"#define MOTD_BYTES (\d+)", SOURCE)[1])


def decode(value):
    escapes = {"n": "\n", "r": "\r", "t": "\t", '"': '"', "^": "^"}
    return re.sub(r"\^(.)", lambda m: escapes.get(m[1], m[1]), value[1:-1])


def constant(name):
    return decode(re.search(r"new const " + name + r"\[\] = (" + STRING + r");", SOURCE)[1])


CATALOG = []
for m in re.finditer(r"\bAdd\((\d+), (" + STRING + r"), (" + STRING + r")(.*?)\);", SOURCE):
    tail = [decode(x) for x in re.findall(STRING, m[4])]
    CATALOG.append(dict(section=int(m[1]), title=decode(m[2]),
                        command=tail[0] if tail else "", owner=tail[1] if len(tail) > 1 else ""))
DIRECT = {decode(x) for x in re.findall(STRING, re.search(r"new const direct\[\]\[\] = \{(.*?)\};", SOURCE, re.S)[1])}
TARGETED = {"uhc_blockdmg_vote", "uhc_blockdmg_set", "uhc_blockdmg_rem"}
BUILD = SOURCE.split("bool:BuildMotd(", 1)[1].split("\nShowHelp(", 1)[0]


def inline(value):
    # Each modeled runtime fragment must actually occur in the Pawn builder.
    assert '"' + value + '"' in BUILD, value
    return value


def render(bots=True, rtv=True, mode=True, damage=True, stats=True, voice=True, admin=False, rules=()):
    fragments = [constant("MOTD_HEAD"), inline("<p>")]
    for enabled, anchor, label in ((bots, "b", "Боты"), (rtv or mode or damage, "v", "Голосования"),
                                    (stats or voice, "p", "Личное")):
        if enabled:
            fragments.append(inline(f"<a href=#{anchor}>{label}</a> "))
    if admin:
        fragments.append(constant("MOTD_NAV_ADMIN"))
    if rules:
        fragments.append(inline(" <a href=#r>Правила</a>"))
    fragments.append(inline("</p>"))
    if bots:
        fragments.append(constant("MOTD_BOTS"))
    if rtv or mode or damage:
        fragments.append(constant("MOTD_VOTES"))
        for enabled, name in ((rtv, "MAP"), (mode, "MODE"), (damage, "DAMAGE")):
            if enabled:
                fragments.append(constant("MOTD_" + name))
    if stats or voice:
        fragments.append(constant("MOTD_PERSONAL"))
        for enabled, name in ((stats, "STATS"), (voice, "MUTE")):
            if enabled:
                fragments.append(constant("MOTD_" + name))
    if admin:
        fragments.append(constant("MOTD_ADMIN"))
    if rules:
        fragments.append(inline("<h2><a name=r></a>Правила</h2>"))
        fragments.extend(html.escape(rule, quote=False) + inline("<br>") for rule in rules)
    fragments.append(constant("MOTD_END"))
    document = "".join(fragments)
    if len(document.encode("utf-8")) > LIMIT:
        raise ValueError("MOTD overflow: no partial document or rules may be sent")
    return document


class Anchors(HTMLParser):
    def __init__(self, document):
        super().__init__()
        self.names, self.links, self.tags = [], [], []
        self.feed(document)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.tags.append(tag)
        if tag == "a":
            if "name" in attrs:
                self.names.append(attrs["name"])
            if "href" in attrs:
                self.links.append(attrs["href"])


def group(entry):
    if entry["owner"] == "statsx_rbs.amxx":
        return "Статистика CS"
    if entry["command"] in ("say /rtv", "say /mode", "uhc_blockdmg_vote"):
        return "Голосования"
    if entry["section"] == 3:
        return {"SprLett-Editor.amxx": "Надписи", "in_game_ads.amxx": "Реклама"}.get(entry["owner"], "Урон игрока")
    return None


class UIContract(unittest.TestCase):
    def test_all_provider_and_role_combinations_fit_and_link(self):
        maximum = 0
        for enabled in itertools.product((False, True), repeat=7):
            doc = render(*enabled)
            maximum = max(maximum, len(doc.encode("utf-8")))
            parsed = Anchors(doc)
            self.assertEqual(len(parsed.names), len(set(parsed.names)))
            for link in parsed.links:
                if link.startswith("#"):
                    self.assertIn(link[1:], parsed.names)
                else:
                    self.assertEqual(link, "https://discord.com/invite/r3kCQNxX5Z")
            self.assertNotIn("script", parsed.tags)
            self.assertEqual("Администратору" in doc, enabled[-1])
            self.assertTrue(doc.endswith("</body></html>"))
        self.assertLessEqual(maximum, LIMIT)
        self.assertLess(LIMIT, 1536)

    def test_no_obsolete_help_menu_or_catalog_noise(self):
        help_code = SOURCE.split("\nShowHelp(id) {", 1)[1]
        self.assertEqual(re.findall(r"show_menu\(([^;]+)\);", help_code), ['id, 0, ""'])
        self.assertIn("g_Section[id] = -1;", help_code)
        self.assertNotIn("g_HelpOpen", SOURCE)
        self.assertNotIn("BuildMotd(entries", SOURCE)
        for unwanted in ("hlxtop", "HLstats", "!help 2", "клавиша Y", "клавиша U"):
            self.assertNotIn(unwanted, SOURCE)

    def test_rules_are_escaped_whole_or_rejected(self):
        doc = render(rules=("<&>",))
        self.assertIn("&lt;&amp;&gt;<br>", doc)
        self.assertIn('href=#r', doc)
        with self.assertRaises(ValueError):
            render(rules=("Я🙂<&>" * 64,) * 64)
        self.assertIn("if (!BuildMotd(", SOURCE)
        self.assertIn("No partial rules shown.", SOURCE)

    def test_group_menus_fit_even_with_all_navigation_controls(self):
        for name in ("Голосования", "Статистика CS", "Урон игрока", "Надписи", "Реклама"):
            entries = [e for e in CATALOG if group(e) == name and e["command"] in DIRECT | TARGETED]
            pages = max(1, (len(entries) + 4) // 5)
            for page in range(pages):
                menu = f"\\yПИКАБУ \\d/ \\w{name} \\d[{page+1}/{pages}]\n\n"
                menu += "".join(f"\\r{i+1}. \\w{e['title']}\n" for i, e in enumerate(entries[page*5:page*5+5]))
                menu += "\n\\r7. \\wНазад\n\\r8. \\wДальше\n\\r9. \\wК разделам админа\n\\r0. \\wВыход"
                self.assertLessEqual(len(menu.encode("utf-8")), 511, name)
        # Source-defined static strings from the complete root (all optional rows).
        root = SOURCE.split("\nShowRoot(id) {", 1)[1].split("\nbool:HasGroup(", 1)[0]
        strings = re.findall(r"formatex\([^\n]+?, (" + STRING + r")\)", root)
        self.assertGreaterEqual(len(strings), 7)
        self.assertLessEqual(sum(len(decode(s).encode("utf-8")) for s in strings), 511)

    def test_command_dispatch_and_vote_context(self):
        self.assertNotIn("slcreate", DIRECT)
        self.assertNotIn("+place_ad", DIRECT)
        self.assertTrue(DIRECT.isdisjoint(TARGETED))
        self.assertTrue(DIRECT.issubset({e["command"] for e in CATALOG}))
        votes = [e for e in CATALOG if group(e) == "Голосования"]
        self.assertEqual(len(votes), 3)
        self.assertTrue(all(e["title"].startswith("За ") for e in votes))
        self.assertIn("Голосование: ограничение урона", SOURCE)
        self.assertIn('amxclient_cmd(id, "say", g_Entries[entry][Command][4]);', SOURCE)
        self.assertIn('find_player("k", g_TargetUserId[id])', SOURCE)
        self.assertIn('if (!ValidTarget(id, entry)', SOURCE)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview-dir", type=Path)
    args = parser.parse_args()
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(UIContract))
    if not result.wasSuccessful():
        raise SystemExit(1)
    if args.preview_dir:
        args.preview_dir.mkdir(parents=True, exist_ok=False)
        for role, admin in (("player", False), ("admin", True)):
            document = render(admin=admin)
            (args.preview_dir / f"{role}.html").write_text(document, encoding="utf-8")
            print(f"{role}: {len(document.encode('utf-8'))} bytes; one page")
