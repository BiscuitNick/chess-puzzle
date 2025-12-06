#!/usr/bin/env python3
"""
Generate a massive puzzle dataset from the full Lichess puzzle database.

Filters for mate-in-1 through mate-in-6 puzzles and validates with Stockfish.

Usage:
    python tools/generate_massive_puzzles.py --input lichess_db_puzzle.csv.zst --output data/puzzles.json --count 10000

    # Skip first 10000 mate puzzles (pagination)
    python tools/generate_massive_puzzles.py --count 10000 --skip 10000

    # Append to existing file
    python tools/generate_massive_puzzles.py --count 10000 --skip 10000 --append

    # Exclude puzzles already in a file
    python tools/generate_massive_puzzles.py --count 10000 --exclude data/puzzles.json
"""

import argparse
import csv
import json
import subprocess
import sys
import time
from pathlib import Path
from collections import defaultdict


class StockfishValidator:
    """Fast Stockfish validator for checkmate verification."""

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
        self._send("setoption name Hash value 128")
        self._send("setoption name Threads value 1")
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

    def validate_checkmate(self, fen: str, moves: str) -> bool:
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
                # If "(none)" - no legal moves = checkmate or stalemate
                return "(none)" in line

        return False

    def stop(self):
        if self.process:
            self._send("quit")
            self.process.wait()
            self.process = None


def parse_mate_in(themes: str) -> int:
    """Extract mate-in-N from themes string."""
    for theme in themes.split():
        if theme.startswith("mateIn"):
            try:
                return int(theme.replace("mateIn", ""))
            except ValueError:
                pass
    return 0


def load_existing_ids(file_path: Path) -> set:
    """Load puzzle IDs from an existing JSON file."""
    if not file_path.exists():
        return set()

    try:
        with open(file_path, 'r') as f:
            data = json.load(f)
            return {p["id"] for p in data.get("puzzles", [])}
    except (json.JSONDecodeError, KeyError):
        return set()


def stream_puzzles(input_file: Path, max_mate_in: int = 6, skip: int = 0, exclude_ids: set = None):
    """
    Stream mate puzzles from compressed Lichess CSV.

    CSV columns: PuzzleId,FEN,Moves,Rating,RatingDeviation,Popularity,NbPlays,Themes,GameUrl,OpeningTags

    Args:
        input_file: Path to the zstd-compressed CSV
        max_mate_in: Maximum mate-in-N to include
        skip: Number of matching puzzles to skip (pagination)
        exclude_ids: Set of puzzle IDs to exclude
    """
    print(f"Streaming puzzles from {input_file}...")
    if skip > 0:
        print(f"  Skipping first {skip} mate puzzles...")
    if exclude_ids:
        print(f"  Excluding {len(exclude_ids)} existing puzzle IDs...")

    proc = subprocess.Popen(
        ["zstd", "-d", "-c", str(input_file)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    reader = csv.reader(proc.stdout)
    next(reader)  # Skip header

    skipped = 0
    exclude_ids = exclude_ids or set()

    for row in reader:
        try:
            puzzle_id = row[0]
            fen = row[1]
            moves = row[2]
            rating = int(row[3])
            themes = row[7] if len(row) > 7 else ""

            mate_in = parse_mate_in(themes)

            # Only include mate puzzles within our range
            if 1 <= mate_in <= max_mate_in:
                # Skip excluded IDs
                if puzzle_id in exclude_ids:
                    continue

                # Handle pagination skip
                if skipped < skip:
                    skipped += 1
                    continue

                yield {
                    "id": puzzle_id,
                    "fen": fen,
                    "moves": moves,
                    "rating": rating,
                    "themes": themes,
                    "mate_in": mate_in
                }
        except (IndexError, ValueError):
            continue

    proc.terminate()


def main():
    parser = argparse.ArgumentParser(description='Generate massive puzzle dataset from Lichess')
    parser.add_argument('--input', '-i', type=Path, default=Path('lichess_db_puzzle.csv.zst'),
                        help='Input Lichess puzzle database (zstd compressed)')
    parser.add_argument('--output', '-o', type=Path, default=Path('data/puzzles.json'),
                        help='Output JSON file')
    parser.add_argument('--stockfish', '-s', type=Path, default=Path('bin/stockfish/macos/stockfish'),
                        help='Path to Stockfish binary')
    parser.add_argument('--count', '-c', type=int, default=10000,
                        help='Target number of puzzles')
    parser.add_argument('--max-mate', '-m', type=int, default=6,
                        help='Maximum mate-in-N to include (default: 6)')
    parser.add_argument('--skip-validation', action='store_true',
                        help='Skip Stockfish validation (faster but less reliable)')
    parser.add_argument('--version', '-v', type=str, default='4.0',
                        help='Version string for output')
    parser.add_argument('--distribution', '-d', type=str, default='balanced',
                        choices=['balanced', 'natural', 'equal'],
                        help='Distribution strategy: balanced (default), natural (as-is), equal')
    parser.add_argument('--skip', type=int, default=0,
                        help='Skip first N mate puzzles (pagination)')
    parser.add_argument('--exclude', '-e', type=Path, default=None,
                        help='Exclude puzzle IDs from this JSON file')
    parser.add_argument('--append', '-a', action='store_true',
                        help='Append to existing output file instead of overwriting')

    args = parser.parse_args()

    if not args.input.exists():
        print(f"Error: Input file not found: {args.input}")
        sys.exit(1)

    if not args.skip_validation and not args.stockfish.exists():
        print(f"Error: Stockfish not found at {args.stockfish}")
        print("Use --skip-validation to skip Stockfish validation")
        sys.exit(1)

    # Load exclusion list
    exclude_ids = set()
    if args.exclude:
        exclude_ids = load_existing_ids(args.exclude)

    # Load existing puzzles if appending
    existing_puzzles = []
    if args.append and args.output.exists():
        try:
            with open(args.output, 'r') as f:
                data = json.load(f)
                existing_puzzles = data.get("puzzles", [])
                # Also exclude these IDs
                exclude_ids.update(p["id"] for p in existing_puzzles)
                print(f"Loaded {len(existing_puzzles)} existing puzzles from {args.output}")
        except (json.JSONDecodeError, KeyError):
            pass

    print("=" * 60)
    print("Massive Puzzle Dataset Generator")
    print("=" * 60)
    print(f"Input:      {args.input}")
    print(f"Output:     {args.output}")
    print(f"Target:     {args.count} new puzzles")
    print(f"Max mate:   mate-in-{args.max_mate}")
    print(f"Validation: {'Disabled' if args.skip_validation else 'Stockfish'}")
    print(f"Distribution: {args.distribution}")
    if args.skip > 0:
        print(f"Skip:       {args.skip} puzzles")
    if exclude_ids:
        print(f"Excluding:  {len(exclude_ids)} puzzle IDs")
    if args.append:
        print(f"Append:     Yes (to {len(existing_puzzles)} existing)")
    print()

    # Calculate distribution targets
    if args.distribution == 'balanced':
        # Weighted distribution favoring shorter mates
        weights = {1: 35, 2: 30, 3: 20, 4: 10, 5: 4, 6: 1}
        total_weight = sum(weights[i] for i in range(1, args.max_mate + 1))
        targets = {i: args.count * weights.get(i, 1) // total_weight for i in range(1, args.max_mate + 1)}
    elif args.distribution == 'equal':
        per_level = args.count // args.max_mate
        targets = {i: per_level for i in range(1, args.max_mate + 1)}
    else:  # natural
        targets = {i: args.count for i in range(1, args.max_mate + 1)}  # No limits

    collected = defaultdict(int)
    valid_puzzles = []
    processed = 0
    invalid_count = 0

    print("Target distribution:")
    for depth in range(1, args.max_mate + 1):
        limit = targets[depth] if args.distribution != 'natural' else '∞'
        print(f"  Mate-in-{depth}: {limit}")
    print()

    # Start validator
    validator = None
    if not args.skip_validation:
        print("Starting Stockfish validator...")
        validator = StockfishValidator(str(args.stockfish))

    start_time = time.time()

    print("Processing puzzles...")
    for puzzle in stream_puzzles(args.input, args.max_mate, skip=args.skip, exclude_ids=exclude_ids):
        # Check if we've met our target
        if args.distribution != 'natural':
            if len(valid_puzzles) >= args.count:
                break

            # Check if we need this mate depth
            depth = puzzle["mate_in"]
            if collected[depth] >= targets[depth]:
                continue

        processed += 1

        # Validate with Stockfish
        if validator:
            is_valid = validator.validate_checkmate(puzzle["fen"], puzzle["moves"])
            if not is_valid:
                invalid_count += 1
                continue

        # Add to collection
        valid_puzzles.append({
            "id": puzzle["id"],
            "fen": puzzle["fen"],
            "moves": puzzle["moves"],
            "rating": puzzle["rating"],
            "themes": puzzle["themes"],
            "mate_in": puzzle["mate_in"]
        })
        collected[puzzle["mate_in"]] += 1

        # Progress updates
        if len(valid_puzzles) % 500 == 0:
            elapsed = time.time() - start_time
            rate = len(valid_puzzles) / elapsed if elapsed > 0 else 0
            print(f"  Collected {len(valid_puzzles)}/{args.count} ({rate:.1f}/sec)")

    if validator:
        validator.stop()

    elapsed = time.time() - start_time

    # Summary
    print()
    print("=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"Processed:  {processed}")
    print(f"Valid:      {len(valid_puzzles)}")
    print(f"Invalid:    {invalid_count}")
    print(f"Time:       {elapsed:.1f}s")
    print()

    print("Distribution collected:")
    for depth in sorted(collected.keys()):
        target = targets.get(depth, '∞')
        print(f"  Mate-in-{depth}: {collected[depth]} / {target}")

    # Rating statistics
    if valid_puzzles:
        ratings = [p["rating"] for p in valid_puzzles]
        print()
        print("Rating statistics:")
        print(f"  Min:    {min(ratings)}")
        print(f"  Max:    {max(ratings)}")
        print(f"  Avg:    {sum(ratings) // len(ratings)}")

    if not valid_puzzles:
        print("\nERROR: No valid puzzles collected!")
        sys.exit(1)

    # Combine with existing puzzles if appending
    all_puzzles = existing_puzzles + valid_puzzles

    # Write output in exact format expected by the game
    output_data = {
        "version": args.version,
        "source": "lichess.org",
        "license": "CC0",
        "generated": time.strftime("%Y-%m-%d %H:%M:%S"),
        "puzzles": all_puzzles
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, 'w') as f:
        json.dump(output_data, f, indent=2)

    file_size = args.output.stat().st_size
    print(f"\n✓ Wrote {len(all_puzzles)} total puzzles to {args.output}")
    if existing_puzzles:
        print(f"  ({len(existing_puzzles)} existing + {len(valid_puzzles)} new)")
    print(f"  File size: {file_size / 1024 / 1024:.2f} MB")


if __name__ == '__main__':
    main()
