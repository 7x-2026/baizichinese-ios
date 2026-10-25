#!/usr/bin/env python3
"""Import text and character colors from 千字中文图.doc using macOS textutil."""

import argparse
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import subprocess
import tempfile


class DocumentParser(HTMLParser):
    def __init__(self, html):
        super().__init__()
        self.colors = {
            name: match.group(1) if (match := re.search(r"color:\s*(#[0-9a-fA-F]{6})", style)) else None
            for name, style in re.findall(r"(?:p|span)\.([\w-]+)\s*\{([^}]+)\}", html)
        }
        self.stack = []
        self.runs = None
        self.paragraphs = []
        self.feed(html)

    def handle_starttag(self, tag, attrs):
        if tag not in ("p", "span"):
            return
        if tag == "p":
            self.runs = []
            self.stack = []
        inherited = self.stack[-1] if self.stack else "#000000"
        color = self.colors.get(dict(attrs).get("class")) or inherited
        self.stack.append(color)

    def handle_data(self, data):
        if self.runs is not None:
            color = self.stack[-1] if self.stack else "#000000"
            text = data.replace("\xa0", " ")
            if self.runs and self.runs[-1]["color"] == color:
                self.runs[-1]["text"] += text
            else:
                self.runs.append({"text": text, "color": color})

    def handle_endtag(self, tag):
        if tag not in ("p", "span"):
            return
        if self.stack:
            self.stack.pop()
        if tag != "p":
            return
        # Remove Word's indentation while preserving spaces within each line.
        while self.runs and not self.runs[0]["text"].lstrip():
            self.runs.pop(0)
        while self.runs and not self.runs[-1]["text"].rstrip():
            self.runs.pop()
        if self.runs:
            self.runs[0]["text"] = self.runs[0]["text"].lstrip()
            self.runs[-1]["text"] = self.runs[-1]["text"].rstrip()
            self.paragraphs.append(self.runs)
        self.runs = None


def paragraph_text(runs):
    return "".join(run["text"] for run in runs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="baizi-thousand-") as temporary:
        html = Path(temporary) / "source.html"
        subprocess.run(["/usr/bin/textutil", "-convert", "html", "-output", str(html), str(args.source)], check=True)
        paragraphs = DocumentParser(html.read_text()).paragraphs

    headings = [
        ("overview", "总图", None),
        ("radicals", "部首图", "中文部首图"),
        ("core", "核心字", "中文百字图（核心字205）"),
        ("extended", "意义延伸字", "中文百字图（意义延伸字160）"),
        ("development", "发展字", "发展字 （714）"),
        ("functional", "功能字词", "功能字词"),
    ]
    sections = []
    legends = []
    for index, (identifier, label, title) in enumerate(headings):
        if index == 0:
            start = 1  # Skip the title containing legacy Word private-use spaces.
            end = next(i for i, p in enumerate(paragraphs) if paragraph_text(p).startswith("红色："))
            title = "中文千字图"
            legends = [paragraph_text(p) for p in paragraphs[end:end + 5]]
        else:
            start = next(i for i, p in enumerate(paragraphs) if paragraph_text(p) == title) + 1
            next_title = headings[index + 1][2] if index + 1 < len(headings) else None
            end = next(i for i, p in enumerate(paragraphs) if paragraph_text(p) == next_title) if next_title else len(paragraphs)
        sections.append({"id": identifier, "label": label, "title": title, "lines": paragraphs[start:end]})

    destination = Path(__file__).resolve().parents[1] / "baizizhongwen/Resources/Texts/thousand-chinese.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps({"sections": sections, "legend": legends}, ensure_ascii=False, indent=2) + "\n")
    print("Imported " + ", ".join(f'{s["label"]}: {len(s["lines"])} lines' for s in sections))


if __name__ == "__main__":
    main()
