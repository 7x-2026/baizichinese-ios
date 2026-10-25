#!/usr/bin/env python3
"""Generate offline zodiac narration with macOS say and afconvert.

Run from any directory: python3 Scripts/generate_zodiac_audio.py
Use --force to regenerate existing recordings after editing the story text.
"""

import argparse
from pathlib import Path
import subprocess
import tempfile


STORIES = Path(__file__).resolve().parents[1] / "baizizhongwen/Resources/Stories/Line23"
VOICES = {"zh": ("Tingting", "175"), "en": ("Samantha", "155")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="Replace existing audio")
    args = parser.parse_args()
    texts = sorted(STORIES.glob("*.txt"))
    if len(texts) != 26:
        raise RuntimeError(f"Expected 26 bilingual story texts, found {len(texts)}")

    with tempfile.TemporaryDirectory(prefix="baizi-zodiac-") as temporary:
        for text in texts:
            output = text.with_suffix(".m4a")
            if output.exists() and not args.force:
                continue
            language = text.stem[-3:-1]
            voice, rate = VOICES[language]
            speech = Path(temporary) / "speech.aiff"
            encoded = Path(temporary) / "speech.m4a"
            # Synthesize the displayed text, including its title, without rewrites.
            subprocess.run([
                "/usr/bin/say", "-v", voice, "-r", rate,
                "-f", str(text), "-o", str(speech),
            ], check=True)
            if speech.stat().st_size <= 4096:
                raise RuntimeError(f"Speech synthesis produced no audio: {text.name}")
            subprocess.run([
                "/usr/bin/afconvert", "-f", "m4af", "-d", "aac@44100",
                "-b", "64000", str(speech), str(encoded),
            ], check=True)
            encoded.replace(output)
            speech.unlink()
            print(f"Generated {output.name}", flush=True)


if __name__ == "__main__":
    main()
