#!/usr/bin/env python3
"""Build the static site in docs/ from site-src/content/*.json.

Run from anywhere: python3 site-src/build.py
Standard library only. Output is plain HTML for GitHub Pages.
"""
import html
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "site-src"
OUT = ROOT / "docs"

SITE_URL = "https://eliasjunit.github.io/vibestretch/"
REPO_URL = "https://github.com/Eliasjunit/vibestretch"
AUTHOR_URL = "https://github.com/Eliasjunit"
VERSION = "0.8.0"

# hreflang code, folder ("" for root), Open Graph locale, text direction
LANGS = [
    ("en", "", "en_US", "ltr"),
    ("es", "es", "es_ES", "ltr"),
    ("pt-BR", "pt-BR", "pt_BR", "ltr"),
    ("fr", "fr", "fr_FR", "ltr"),
    ("de", "de", "de_DE", "ltr"),
    ("it", "it", "it_IT", "ltr"),
    ("ru", "ru", "ru_RU", "ltr"),
    ("uk", "uk", "uk_UA", "ltr"),
    ("pl", "pl", "pl_PL", "ltr"),
    ("tr", "tr", "tr_TR", "ltr"),
    ("nl", "nl", "nl_NL", "ltr"),
    ("sv", "sv", "sv_SE", "ltr"),
    ("da", "da", "da_DK", "ltr"),
    ("nb", "nb", "nb_NO", "ltr"),
    ("fi", "fi", "fi_FI", "ltr"),
    ("cs", "cs", "cs_CZ", "ltr"),
    ("ro", "ro", "ro_RO", "ltr"),
    ("hu", "hu", "hu_HU", "ltr"),
    ("el", "el", "el_GR", "ltr"),
    ("ja", "ja", "ja_JP", "ltr"),
    ("ko", "ko", "ko_KR", "ltr"),
    ("zh-Hans", "zh-Hans", "zh_CN", "ltr"),
    ("zh-Hant", "zh-Hant", "zh_TW", "ltr"),
    ("id", "id", "id_ID", "ltr"),
    ("th", "th", "th_TH", "ltr"),
    ("vi", "vi", "vi_VN", "ltr"),
    ("ms", "ms", "ms_MY", "ltr"),
    ("hi", "hi", "hi_IN", "ltr"),
    ("ar", "ar", "ar_AR", "rtl"),
    ("he", "he", "he_IL", "rtl"),
]

# Page slugs in navigation order. "index" is the language home.
PAGES = [
    "index",
    "stretch-breaks-ai-coding-agents",
    "20-20-20-eye-rule-developers",
    "desk-stretches-programmers",
    "claude-code-break-reminder",
    "codex-cli-break-reminder",
    "gemini-cli-break-reminder",
]

# Commands and sample output stay the same in every language.
CODE = {
    "install_claude_cli": "claude plugin marketplace add Eliasjunit/vibestretch && claude plugin install vibestretch@vibestretch",
    "install_claude": "/plugin marketplace add Eliasjunit/vibestretch\n/plugin install vibestretch@vibestretch",
    "install_codex": "codex plugin marketplace add Eliasjunit/vibestretch\ncodex plugin add vibestretch@vibestretch",
    "install_codex_manual": "git clone https://github.com/Eliasjunit/vibestretch ~/.codex/vibestretch\ncp ~/.codex/vibestretch/hooks/codex-hooks.json ~/.codex/hooks.json",
    "install_gemini_clone": "git clone https://github.com/Eliasjunit/vibestretch ~/.gemini/vibestretch",
    "install_gemini_merge": "jq -s '.[0] * .[1]' ~/.gemini/settings.json ~/.gemini/vibestretch/hooks/gemini-hooks.json > /tmp/s.json && mv /tmp/s.json ~/.gemini/settings.json",
    "statusline": "/vibestretch:statusline",
    "nudge_example": "\U0001f9d8 Wrist circles, 10 each way. Your tendons will thank you. · vibestretch · 7 min of agent time",
    "nudge_202020": "\U0001f9d8 20-20-20: look at something 20 feet away for 20 seconds.",
    "custom_list": "mkdir -p ~/.config/vibestretch\ncat > ~/.config/vibestretch/exercises.txt <<'EOF'\n# blank lines and comments are skipped\nRefill the water glass. Yes, now.\nHang from the pull-up bar for 20 seconds.\nLook out the window and find something green.\nEOF",
}

SETTINGS = [
    ("VIBESTRETCH_MIN_TURN", "120"),
    ("VIBESTRETCH_MIN_ACTIVE", "300"),
    ("VIBESTRETCH_COOLDOWN", "900"),
    ("VIBESTRETCH_AWAY", "300"),
    ("VIBESTRETCH_DISABLE", "unset"),
    ("VIBESTRETCH_NOTIFY", "1"),
    ("VIBESTRETCH_SOUND", "1"),
    ("VIBESTRETCH_EXERCISES", "~/.config/vibestretch/exercises.txt"),
]

CSS = """:root{--bg:#fbfaf7;--fg:#1d1d1b;--muted:#5d5d58;--line:#e2e0d9;--accent:#2f7d4f;--code:#f0eee8}
@media (prefers-color-scheme:dark){:root{--bg:#151614;--fg:#ecebe6;--muted:#a6a59e;--line:#2d2e2b;--accent:#6cc28f;--code:#21221f}}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{margin:0;background:var(--bg);color:var(--fg);font:17px/1.6 system-ui,-apple-system,"Segoe UI",Roboto,"Noto Sans",sans-serif}
a{color:var(--accent)}
.skip{position:absolute;inset-inline-start:-999px}
.skip:focus{inset-inline-start:16px;top:8px;background:var(--bg);padding:4px 8px}
.wrap{max-width:760px;margin:0 auto;padding:0 16px}
header.site{border-bottom:1px solid var(--line)}
header.site .wrap{display:flex;flex-wrap:wrap;gap:8px 16px;align-items:center;justify-content:space-between;padding-block:12px}
.brand{display:flex;gap:8px;align-items:center;font-weight:700;text-decoration:none;color:var(--fg)}
.brand img{width:28px;height:28px;border-radius:6px}
details.lang{position:relative}
details.lang summary{cursor:pointer;color:var(--muted)}
details.lang ul{position:absolute;inset-inline-end:0;z-index:2;margin:6px 0 0;padding:8px;list-style:none;background:var(--bg);border:1px solid var(--line);border-radius:8px;columns:2;column-gap:16px;width:min(340px,90vw)}
details.lang li a{display:block;padding:2px 4px;text-decoration:none}
details.lang li a[aria-current]{font-weight:700;color:var(--fg)}
nav.pages ul{display:flex;flex-wrap:wrap;gap:4px 14px;list-style:none;margin:0;padding:10px 0;font-size:15px}
nav.pages a[aria-current]{color:var(--fg);font-weight:600;text-decoration:none}
nav.crumbs{font-size:14px;color:var(--muted);margin-top:16px}
nav.crumbs ol{list-style:none;margin:0;padding:0;display:flex;flex-wrap:wrap;gap:6px}
nav.crumbs li+li::before{content:"/";margin-inline-end:6px}
h1{font-size:2rem;line-height:1.2;margin:.6em 0 .3em}
h2{font-size:1.3rem;margin:1.8em 0 .4em}
.lead{font-size:1.1rem;color:var(--muted)}
pre{background:var(--code);border:1px solid var(--line);border-radius:8px;padding:12px 14px;overflow-x:auto;font-size:14px;line-height:1.5}
pre,code{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;direction:ltr;unicode-bidi:isolate}
pre{text-align:left}
p code,li code,td code,dd code{background:var(--code);padding:1px 5px;border-radius:4px;font-size:.9em;overflow-wrap:anywhere}
main{overflow-wrap:break-word}
.table{overflow-x:auto}
table{border-collapse:collapse;width:100%;font-size:15px}
th,td{border-bottom:1px solid var(--line);padding:6px 8px;text-align:start;vertical-align:top}
.faq dt{font-weight:700;margin-top:1em}
.faq dd{margin:0.2em 0 0}
.related ul{padding-inline-start:1.2em}
footer.site{border-top:1px solid var(--line);margin-top:48px;padding-block:20px;color:var(--muted);font-size:14px}
"""


def url_for(folder, slug):
    path = (folder + "/") if folder else ""
    if slug != "index":
        path += slug + "/"
    return SITE_URL + path


def out_path(folder, slug):
    p = OUT / folder if folder else OUT
    if slug != "index":
        p = p / slug
    return p / "index.html"


def rel_prefix(folder, slug):
    depth = (1 if folder else 0) + (0 if slug == "index" else 1)
    return "../" * depth or "./"


def inline(text, folder, slug):
    """Escape text and apply `code`, **bold** and [label](@slug) links."""
    prefix = rel_prefix(folder, slug)
    out = []
    pos = 0
    pattern = re.compile(r"`([^`]+)`|\*\*([^*]+)\*\*|\[([^\]]+)\]\(@([a-z0-9-]+)\)")
    for m in pattern.finditer(text):
        out.append(html.escape(text[pos:m.start()], quote=False))
        if m.group(1) is not None:
            out.append("<code>" + html.escape(m.group(1), quote=False) + "</code>")
        elif m.group(2) is not None:
            out.append("<strong>" + html.escape(m.group(2), quote=False) + "</strong>")
        else:
            target = m.group(4)
            if target not in PAGES:
                raise SystemExit(f"unknown link target {target!r} in {folder or 'en'}/{slug}")
            href = prefix + ((folder + "/") if folder else "") + ("" if target == "index" else target + "/")
            out.append(f'<a href="{href}">' + html.escape(m.group(3), quote=False) + "</a>")
        pos = m.end()
    out.append(html.escape(text[pos:], quote=False))
    return "".join(out)


def strip_inline(text):
    text = re.sub(r"\[([^\]]+)\]\(@[a-z0-9-]+\)", r"\1", text)
    return text.replace("`", "").replace("**", "")


def render_blocks(blocks, content, folder, slug):
    parts = []
    for b in blocks:
        if "h2" in b:
            parts.append(f"<h2>{inline(b['h2'], folder, slug)}</h2>")
        elif "p" in b:
            parts.append(f"<p>{inline(b['p'], folder, slug)}</p>")
        elif "ul" in b or "ol" in b:
            tag = "ul" if "ul" in b else "ol"
            items = "".join(f"<li>{inline(i, folder, slug)}</li>" for i in b[tag])
            parts.append(f"<{tag}>{items}</{tag}>")
        elif "code" in b:
            parts.append(f'<pre><code>{html.escape(CODE[b["code"]], quote=False)}</code></pre>')
        elif "table" in b:
            head = content["settings_head"]
            rows = content["settings_rows"]
            trs = "".join(
                f"<tr><td><code>{k}</code></td><td><code>{html.escape(v)}</code></td><td>{inline(rows[k], folder, slug)}</td></tr>"
                for k, v in SETTINGS
            )
            parts.append(
                '<div class="table"><table><thead><tr>'
                + "".join(f"<th>{html.escape(h)}</th>" for h in head)
                + f"</tr></thead><tbody>{trs}</tbody></table></div>"
            )
        else:
            raise SystemExit(f"unknown block {b!r}")
    return "\n".join(parts)


def jsonld(content, code, folder, slug, page):
    url = url_for(folder, slug)
    home = url_for(folder, "index")
    org = {"@type": "Organization", "@id": SITE_URL + "#org", "name": "Junit", "url": AUTHOR_URL}
    app = {
        "@type": "SoftwareApplication",
        "@id": SITE_URL + "#app",
        "name": "vibestretch",
        "applicationCategory": "DeveloperApplication",
        "operatingSystem": "macOS, Linux",
        "softwareVersion": VERSION,
        "license": "https://opensource.org/licenses/MIT",
        "url": REPO_URL,
        "downloadUrl": REPO_URL,
        "description": content["pages"]["index"]["description"],
        "author": {"@id": SITE_URL + "#org"},
    }
    crumbs = [{"@type": "ListItem", "position": 1, "name": content["ui"]["breadcrumb_home"], "item": home}]
    if slug != "index":
        crumbs.append({"@type": "ListItem", "position": 2, "name": page["h1"], "item": url})
    webpage = {
        "@type": "WebPage",
        "@id": url + "#webpage",
        "url": url,
        "name": page["title"],
        "description": page["description"],
        "inLanguage": code,
        "isPartOf": {"@type": "WebSite", "@id": SITE_URL + "#website", "name": "vibestretch", "url": SITE_URL, "publisher": {"@id": SITE_URL + "#org"}},
        "about": {"@id": SITE_URL + "#app"},
        "breadcrumb": {"@id": url + "#breadcrumb"},
        "primaryImageOfPage": SITE_URL + "assets/social-preview.png",
    }
    graph = [org, app, webpage, {"@type": "BreadcrumbList", "@id": url + "#breadcrumb", "itemListElement": crumbs}]
    if page.get("faq"):
        graph.append({
            "@type": "FAQPage",
            "@id": url + "#faq",
            "url": url,
            "inLanguage": code,
            "mainEntity": [
                {"@type": "Question", "name": strip_inline(f["q"]),
                 "acceptedAnswer": {"@type": "Answer", "text": strip_inline(f["a"])}}
                for f in page["faq"]
            ],
        })
    data = json.dumps({"@context": "https://schema.org", "@graph": graph}, ensure_ascii=False, indent=1)
    return data.replace("</", "<\\/")


def render(all_content, code, folder, ogl, direction, slug):
    content = all_content[code]
    ui = content["ui"]
    page = content["pages"][slug]
    prefix = rel_prefix(folder, slug)
    url = url_for(folder, slug)

    alternates = "\n".join(
        f'<link rel="alternate" hreflang="{c}" href="{url_for(f, slug)}">' for c, f, _, _ in LANGS
    ) + f'\n<link rel="alternate" hreflang="x-default" href="{url_for("", slug)}">'

    lang_items = "".join(
        f'<li><a href="{prefix}{(f + "/") if f else ""}{"" if slug == "index" else slug + "/"}" hreflang="{c}" lang="{c}"'
        + (' aria-current="true"' if c == code else "")
        + f">{html.escape(all_content[c]['lang_name'])}</a></li>"
        for c, f, _, _ in LANGS
    )

    nav_items = "".join(
        f'<li><a href="{prefix}{(folder + "/") if folder else ""}{"" if s == "index" else s + "/"}"'
        + (' aria-current="page"' if s == slug else "")
        + f">{html.escape(content['pages'][s]['nav'])}</a></li>"
        for s in PAGES
    )

    home_href = prefix + ((folder + "/") if folder else "")
    crumbs = f'<li><a href="{home_href}">{html.escape(ui["breadcrumb_home"])}</a></li>'
    if slug != "index":
        crumbs += f'<li aria-current="page">{html.escape(page["h1"])}</li>'

    faq = ""
    if page.get("faq"):
        faq = f'<section class="faq" id="faq"><h2>{html.escape(ui["faq_title"])}</h2><dl>' + "".join(
            f"<dt>{inline(f['q'], folder, slug)}</dt><dd>{inline(f['a'], folder, slug)}</dd>" for f in page["faq"]
        ) + "</dl></section>"

    related = [s for s in PAGES if s != slug][:6]
    related_html = f'<section class="related"><h2>{html.escape(ui["related_title"])}</h2><ul>' + "".join(
        f'<li><a href="{prefix}{(folder + "/") if folder else ""}{"" if s == "index" else s + "/"}">{html.escape(content["pages"][s]["h1"])}</a></li>'
        for s in related
    ) + "</ul></section>"

    og_alt = "\n".join(f'<meta property="og:locale:alternate" content="{o}">' for c, _, o, _ in LANGS if c != code)

    return f"""<!doctype html>
<html lang="{code}" dir="{direction}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(page["title"])}</title>
<meta name="description" content="{html.escape(page["description"])}">
<link rel="canonical" href="{url}">
{alternates}
<meta property="og:type" content="website">
<meta property="og:site_name" content="vibestretch">
<meta property="og:title" content="{html.escape(page["title"])}">
<meta property="og:description" content="{html.escape(page["description"])}">
<meta property="og:url" content="{url}">
<meta property="og:image" content="{SITE_URL}assets/social-preview.png">
<meta property="og:locale" content="{ogl}">
{og_alt}
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="{prefix}assets/icon.png" type="image/png">
<link rel="stylesheet" href="{prefix}assets/style.css">
<link rel="sitemap" type="application/xml" href="{SITE_URL}sitemap.xml">
<script type="application/ld+json">
{jsonld(content, code, folder, slug, page)}
</script>
</head>
<body>
<a class="skip" href="#main">{html.escape(ui["skip"])}</a>
<header class="site"><div class="wrap">
<a class="brand" href="{home_href}"><img src="{prefix}assets/icon.png" alt="" width="28" height="28">vibestretch</a>
<details class="lang"><summary>{html.escape(ui["languages"])}: {html.escape(content["lang_name"])}</summary><ul>{lang_items}</ul></details>
</div>
<nav class="pages wrap" aria-label="{html.escape(ui["nav_label"])}"><ul>{nav_items}</ul></nav>
</header>
<main id="main" class="wrap">
<nav class="crumbs" aria-label="{html.escape(ui["breadcrumb_label"])}"><ol>{crumbs}</ol></nav>
<h1>{inline(page["h1"], folder, slug)}</h1>
<p class="lead">{inline(page["lead"], folder, slug)}</p>
{render_blocks(page["blocks"], content, folder, slug)}
{faq}
{related_html}
</main>
<footer class="site"><div class="wrap">
<p>{html.escape(ui["footer_license"])} {html.escape(ui["footer_made"])} <a href="{REPO_URL}">{html.escape(ui["source_link"])}</a></p>
</div></footer>
</body>
</html>
"""


def sitemap():
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">']
    for slug in PAGES:
        alts = "".join(
            f'\n    <xhtml:link rel="alternate" hreflang="{c}" href="{url_for(f, slug)}"/>' for c, f, _, _ in LANGS
        ) + f'\n    <xhtml:link rel="alternate" hreflang="x-default" href="{url_for("", slug)}"/>'
        for _, folder, _, _ in LANGS:
            lines.append(f"  <url>\n    <loc>{url_for(folder, slug)}</loc>{alts}\n  </url>")
    lines.append("</urlset>\n")
    return "\n".join(lines)


ROBOTS = """# Search engines and AI assistants are welcome to read this site.
User-agent: *
Allow: /

User-agent: Googlebot
Allow: /

User-agent: Bingbot
Allow: /

User-agent: Google-Extended
Allow: /

User-agent: GPTBot
Allow: /

User-agent: OAI-SearchBot
Allow: /

User-agent: ChatGPT-User
Allow: /

User-agent: ClaudeBot
Allow: /

User-agent: Claude-SearchBot
Allow: /

User-agent: Claude-User
Allow: /

User-agent: anthropic-ai
Allow: /

User-agent: PerplexityBot
Allow: /

User-agent: Perplexity-User
Allow: /

User-agent: Applebot
Allow: /

User-agent: Applebot-Extended
Allow: /

User-agent: CCBot
Allow: /

User-agent: Meta-ExternalAgent
Allow: /

User-agent: Amazonbot
Allow: /

User-agent: DuckAssistBot
Allow: /

User-agent: YandexBot
Allow: /

Sitemap: {site}sitemap.xml
"""


def main():
    all_content = {}
    for code, *_ in LANGS:
        all_content[code] = json.loads((SRC / "content" / f"{code}.json").read_text(encoding="utf-8"))

    # Every translation must cover every page, block and setting of the English source.
    en = all_content["en"]
    for code, content in all_content.items():
        for slug in PAGES:
            p, e = content["pages"][slug], en["pages"][slug]
            for b, eb in zip(p["blocks"], e["blocks"], strict=True):
                if set(b) != set(eb) or ("code" in b and b["code"] != eb["code"]):
                    raise SystemExit(f"{code}/{slug}: block {b!r} does not match {eb!r}")
                for k in ("ul", "ol"):
                    if k in b and len(b[k]) != len(eb[k]):
                        raise SystemExit(f"{code}/{slug}: list length differs")
            if len(p.get("faq", [])) != len(e.get("faq", [])):
                raise SystemExit(f"{code}/{slug}: faq length differs")
        if set(content["settings_rows"]) != set(en["settings_rows"]):
            raise SystemExit(f"{code}: settings_rows differ")

    if OUT.exists():
        shutil.rmtree(OUT)
    (OUT / "assets").mkdir(parents=True)
    (OUT / "assets" / "style.css").write_text(CSS, encoding="utf-8")
    for name in ("icon.png", "social-preview.png"):
        shutil.copy(ROOT / "assets" / name, OUT / "assets" / name)
    (OUT / ".nojekyll").write_text("", encoding="utf-8")

    count = 0
    for code, folder, ogl, direction in LANGS:
        for slug in PAGES:
            path = out_path(folder, slug)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(render(all_content, code, folder, ogl, direction, slug), encoding="utf-8")
            count += 1

    (OUT / "sitemap.xml").write_text(sitemap(), encoding="utf-8")
    (OUT / "robots.txt").write_text(ROBOTS.format(site=SITE_URL), encoding="utf-8")
    print(f"built {count} pages in {len(LANGS)} languages")


if __name__ == "__main__":
    main()
