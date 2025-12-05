#!/usr/bin/env python3
"""
Generate a clean, validated puzzle dataset from Lichess database.

Downloads the Lichess puzzle CSV, filters for mate puzzles,
validates each with Stockfish, and outputs only verified checkmates.

Usage:
    python tools/generate_puzzle_dataset.py --count 50 --output data/puzzles.json
"""

import argparse
import csv
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Generator

# Lichess puzzle database URL
LICHESS_DB_URL = "https://database.lichess.org/lichess_db_puzzle.csv.zst"
CACHE_DIR = Path("data/.cache")
CACHE_FILE = CACHE_DIR / "lichess_db_puzzle.csv.zst"


class StockfishValidator:
    """Validates puzzles using Stockfish engine."""

    def __init__(self, stockfish_path: str):
        self.path = stockfish_path
        self.process = None
        self._start()

    def _start(self):
        """Start Stockfish process."""
        self.process = subprocess.Popen(
            [self.path],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1
        )
        self._send("uci")
        self._wait_for("uciok")
        self._send("isready")
        self._wait_for("readyok")

    def _send(self, command: str):
        self.process.stdin.write(command + "\n")
        self.process.stdin.flush()

    def _wait_for(self, expected: str, timeout_lines: int = 100) -> list:
        lines = []
        for _ in range(timeout_lines):
            line = self.process.stdout.readline().strip()
            lines.append(line)
            if line.startswith(expected):
                break
        return lines

    def validate_checkmate(self, fen: str, moves: str) -> tuple[bool, str]:
        """Validate that applying moves to FEN results in checkmate."""
        self._send("ucinewgame")
        self._send("isready")
        self._wait_for("readyok")

        if moves:
            self._send(f"position fen {fen} moves {moves}")
        else:
            self._send(f"position fen {fen}")

        self._send("go depth 1")

        while True:
            line = self.process.stdout.readline().strip()
            if line.startswith("bestmove"):
                if "(none)" in line:
                    return True, "Checkmate"
                return False, f"Has moves: {line}"

        return False, "Timeout"

    def stop(self):
        if self.process:
            self._send("quit")
            self.process.wait()
            self.process = None


def download_lichess_db() -> Path:
    """Download Lichess puzzle database if not cached."""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)

    if CACHE_FILE.exists():
        print(f"Using cached: {CACHE_FILE}")
        return CACHE_FILE

    print(f"Downloading Lichess puzzle database...")
    print(f"  URL: {LICHESS_DB_URL}")
    print(f"  This may take a few minutes (~300MB)...")

    result = subprocess.run(
        ["curl", "-L", "-o", str(CACHE_FILE), LICHESS_DB_URL],
        capture_output=True, text=True
    )

    if result.returncode != 0:
        print(f"Download failed: {result.stderr}")
        sys.exit(1)

    print(f"  Downloaded to: {CACHE_FILE}")
    return CACHE_FILE


def stream_mate_puzzles(db_file: Path, max_puzzles: int = 10000) -> Generator[dict, None, None]:
    """
    Stream puzzles from the compressed Lichess CSV, filtering for mate puzzles.
    Uses zstd to decompress on-the-fly.
    """
    print(f"Streaming puzzles from {db_file}...")

    # CSV columns: PuzzleId,FEN,Moves,Rating,RatingDeviation,Popularity,NbPlays,Themes,GameUrl,OpeningTags
    proc = subprocess.Popen(
        ["zstd", "-d", "-c", str(db_file)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    reader = csv.reader(proc.stdout)
    header = next(reader)  # Skip header

    count = 0
    for row in reader:
        if count >= max_puzzles:
            break

        try:
            puzzle_id = row[0]
            fen = row[1]
            moves = row[2]
            rating = int(row[3])
            themes = row[7] if len(row) > 7 else ""

            # Check if it's a mate puzzle
            mate_in = 0
            for theme in themes.split():
                if theme.startswith("mateIn"):
                    try:
                        mate_in = int(theme.replace("mateIn", ""))
                        break
                    except ValueError:
                        pass

            if mate_in > 0:
                count += 1
                yield {
                    "id": puzzle_id,
                    "fen": fen,
                    "moves": moves,
                    "rating": rating,
                    "themes": themes,
                    "mate_in": mate_in
                }

        except (IndexError, ValueError) as e:
            continue

    proc.terminate()


def main():
    parser = argparse.ArgumentParser(description='Generate validated puzzle dataset')
    parser.add_argument('--count', '-c', type=int, default=50,
                        help='Number of puzzles to generate')
    parser.add_argument('--output', '-o', type=Path, default=Path('data/puzzles.json'),
                        help='Output JSON file')
    parser.add_argument('--stockfish', '-s', type=Path,
                        default=Path('bin/stockfish/macos/stockfish'),
                        help='Path to Stockfish binary')
    parser.add_argument('--version', '-v', type=str, default='3.0',
                        help='Version string for output')
    parser.add_argument('--skip-download', action='store_true',
                        help='Skip download, use existing cache')

    args = parser.parse_args()

    if not args.stockfish.exists():
        print(f"Error: Stockfish not found at {args.stockfish}")
        sys.exit(1)

    print("=" * 60)
    print("Validated Puzzle Dataset Generator")
    print("=" * 60)
    print(f"Target: {args.count} puzzles")
    print(f"Stockfish: {args.stockfish}")
    print(f"Output: {args.output}")
    print()

    # Download database
    if not args.skip_download:
        db_file = download_lichess_db()
    else:
        db_file = CACHE_FILE
        if not db_file.exists():
            print(f"Error: Cache file not found: {db_file}")
            sys.exit(1)

    # Start validator
    print("\nStarting Stockfish validator...")
    validator = StockfishValidator(str(args.stockfish))

    valid_puzzles = []
    invalid_count = 0
    processed = 0

    # Distribution targets
    targets = {
        1: args.count * 40 // 100,  # 40% mate-in-1
        2: args.count * 30 // 100,  # 30% mate-in-2
        3: args.count * 20 // 100,  # 20% mate-in-3
        4: args.count * 10 // 100,  # 10% mate-in-4+
    }
    collected = {1: 0, 2: 0, 3: 0, 4: 0}

    print(f"\nTarget distribution:")
    print(f"  Mate-in-1: {targets[1]}")
    print(f"  Mate-in-2: {targets[2]}")
    print(f"  Mate-in-3: {targets[3]}")
    print(f"  Mate-in-4+: {targets[4]}")
    print()

    print("Validating puzzles...")
    for puzzle in stream_mate_puzzles(db_file, max_puzzles=50000):
        if len(valid_puzzles) >= args.count:
            break

        # Check if we still need this mate depth
        depth_key = min(puzzle["mate_in"], 4)
        if collected[depth_key] >= targets[depth_key]:
            continue

        processed += 1

        # Validate with Stockfish
        is_valid, reason = validator.validate_checkmate(
            puzzle["fen"],
            puzzle["moves"]
        )

        if is_valid:
            valid_puzzles.append({
                "id": puzzle["id"],
                "fen": puzzle["fen"],
                "moves": puzzle["moves"],
                "rating": puzzle["rating"],
                "themes": puzzle["themes"],
                "mate_in": puzzle["mate_in"]
            })
            collected[depth_key] += 1
            print(f"  ✓ [{len(valid_puzzles)}/{args.count}] {puzzle['id']}: mate-in-{puzzle['mate_in']}, rating {puzzle['rating']}")
        else:
            invalid_count += 1
            if invalid_count <= 10:  # Only show first 10 invalid
                print(f"  ✗ {puzzle['id']}: {reason}")

        # Progress every 100
        if processed % 100 == 0:
            print(f"  ... processed {processed}, found {len(valid_puzzles)} valid")

    validator.stop()

    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"Processed: {processed}")
    print(f"Valid:     {len(valid_puzzles)}")
    print(f"Invalid:   {invalid_count}")
    print()

    print("Distribution:")
    for depth in sorted(collected.keys()):
        label = f"Mate-in-{depth}" if depth < 4 else "Mate-in-4+"
        print(f"  {label}: {collected[depth]}")

    if not valid_puzzles:
        print("\nERROR: No valid puzzles!")
        sys.exit(1)

    # Write output
    output_data = {
        "version": args.version,
        "source": "lichess.org",
        "license": "CC0",
        "generated": time.strftime("%Y-%m-%d %H:%M:%S"),
        "puzzles": valid_puzzles
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, 'w') as f:
        json.dump(output_data, f, indent=2)

    print(f"\n✓ Wrote {len(valid_puzzles)} validated puzzles to {args.output}")


if __name__ == '__main__':
    main()
