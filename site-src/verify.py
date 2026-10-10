#!/usr/bin/env python3
"""Check the built site in docs/. Run after build.py: python3 site-src/verify.py

Needs html5lib (pip install html5lib) for strict HTML parsing.
"""
import json
import re
import sys
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin, urlparse

import html5lib

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build import SITE_URL  # noqa: E402

EM_DASH = chr(0x2014)
problems = []


def url_to_file(url):
    if not url.startswith(SITE_URL):
        return None
    rest = url[len(SITE_URL):]
    return DOCS / rest / "index.html" if (rest == "" or rest.endswith("/")) else DOCS / rest


class Collect(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links, self.hrefs, self.ld, self.meta = [], [], [], {}
        self.html_attrs, self.title, self._in_title, self._in_ld = {}, "", False, False
        self.faq_section = False

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "html":
            self.html_attrs = a
        elif tag == "link":
            self.links.append(a)
        elif tag == "a" and "href" in a:
            self.hrefs.append(a["href"])
        elif tag == "meta":
            self.meta[a.get("name") or a.get("property")] = a.get("content")
        elif tag == "title":
            self._in_title = True
        elif tag == "script" and a.get("type") == "application/ld+json":
            self._in_ld = True
            self.ld.append("")
        elif tag == "section" and "faq" in (a.get("class") or ""):
            self.faq_section = True

    def handle_endtag(self, tag):
        if tag == "title":
            self._in_title = False
        if tag == "script":
            self._in_ld = False

    def handle_data(self, data):
        if self._in_title:
            self.title += data
        if self._in_ld:
            self.ld[-1] += data


pages = sorted(DOCS.rglob("*.html"))
parser = html5lib.HTMLParser(strict=True)
info = {}
for path in pages:
    text = path.read_text(encoding="utf-8")
    try:
        parser.parse(text)
    except Exception as e:  # html5lib raises ParseError on the first problem
        problems.append(f"parse error in {path.relative_to(DOCS)}: {e}")
    c = Collect()
    c.feed(text)
    info[path] = c

# Em dashes anywhere in the site, its sources and the README.
for path in list(DOCS.rglob("*")) + list((ROOT / "site-src").rglob("*")) + [ROOT / "README.md"]:
    if path.is_file() and path.suffix in {".html", ".xml", ".txt", ".css", ".json", ".py", ".md"}:
        if EM_DASH in path.read_text(encoding="utf-8"):
            problems.append(f"em dash in {path.relative_to(ROOT)}")

titles, descs = {}, {}
own_url = {}
for path, c in info.items():
    canon = [l["href"] for l in c.links if l.get("rel") == "canonical"]
    if len(canon) != 1:
        problems.append(f"{path}: needs exactly one canonical")
        continue
    own_url[path] = canon[0]
    if url_to_file(canon[0]) != path:
        problems.append(f"{path}: canonical {canon[0]} points elsewhere")
    titles.setdefault(c.title, []).append(path)
    descs.setdefault(c.meta.get("description"), []).append(path)
    for key in ("og:title", "og:description", "og:url", "og:image", "og:locale"):
        if not c.meta.get(key):
            problems.append(f"{path}: missing {key}")
    lang = c.html_attrs.get("lang")
    want_dir = "rtl" if lang in ("ar", "he") else "ltr"
    if c.html_attrs.get("dir") != want_dir:
        problems.append(f"{path}: dir should be {want_dir}")

    # JSON-LD
    types = set()
    for block in c.ld:
        try:
            data = json.loads(block.replace("<\\/", "</"))
        except ValueError as e:
            problems.append(f"{path}: bad JSON-LD: {e}")
            continue
        for node in data.get("@graph", []):
            types.add(node["@type"])
            if "aggregateRating" in node:
                problems.append(f"{path}: aggregateRating present")
    for t in ("Organization", "WebPage", "BreadcrumbList", "SoftwareApplication"):
        if t not in types:
            problems.append(f"{path}: JSON-LD lacks {t}")
    if ("FAQPage" in types) != c.faq_section:
        problems.append(f"{path}: FAQPage and visible FAQ do not match")

    # Internal links resolve to files.
    for href in c.hrefs:
        if urlparse(href).scheme:
            continue
        target = (path.parent / href.split("#")[0]).resolve()
        if target.is_dir():
            target = target / "index.html"
        if not target.exists():
            problems.append(f"{path}: broken link {href}")

for t, ps in titles.items():
    if len(ps) > 1:
        problems.append(f"duplicate title {t!r} on {len(ps)} pages")
for d, ps in descs.items():
    if len(ps) > 1:
        problems.append(f"duplicate description on {len(ps)} pages")

# hreflang: target exists, self-reference, x-default, reciprocal.
alts = {}
for path, c in info.items():
    alts[path] = {l["hreflang"]: l["href"] for l in c.links if l.get("rel") == "alternate" and l.get("hreflang")}
hreflang_links = 0
for path, a in alts.items():
    if "x-default" not in a:
        problems.append(f"{path}: no x-default")
    if own_url.get(path) not in a.values():
        problems.append(f"{path}: no self-referencing hreflang")
    for code, href in a.items():
        hreflang_links += 1
        target = url_to_file(href)
        if target is None or not target.exists():
            problems.append(f"{path}: hreflang {code} target missing: {href}")
        elif own_url[path] not in alts[target].values():
            problems.append(f"{path}: hreflang {code} not reciprocal from {href}")

# Sitemap
ns = {"s": "http://www.sitemaps.org/schemas/sitemap/0.9"}
tree = ET.parse(DOCS / "sitemap.xml")
locs = [u.find("s:loc", ns).text for u in tree.getroot().findall("s:url", ns)]
html_pages = [p for p in pages]
if len(locs) != len(html_pages) or len(set(locs)) != len(locs):
    problems.append(f"sitemap has {len(locs)} URLs, site has {len(html_pages)} pages")
for loc in locs:
    f = url_to_file(loc)
    if f is None or not f.exists():
        problems.append(f"sitemap URL without page: {loc}")
if set(own_url.values()) != set(locs):
    problems.append("sitemap URLs and canonical URLs differ")

robots = (DOCS / "robots.txt").read_text(encoding="utf-8")
if "Disallow" in robots or f"Sitemap: {SITE_URL}sitemap.xml" not in robots:
    problems.append("robots.txt must allow all and point to the sitemap")

langs = sorted({c.html_attrs.get("lang") for c in info.values()})
print(f"HTML pages parsed (html5lib strict): {len(pages)}")
print(f"languages: {len(langs)}")
print(f"pages per language: {len(pages) // max(len(langs), 1)}")
print(f"hreflang links checked: {hreflang_links}")
print(f"sitemap URLs: {len(locs)}")
print(f"unique titles: {len(titles)}, unique descriptions: {len(descs)}")
print(f"em dash characters: {sum(1 for p in problems if p.startswith('em dash'))} files")
if problems:
    print(f"\n{len(problems)} problems:")
    print("\n".join(problems[:200]))
    sys.exit(1)
print("all checks passed")
