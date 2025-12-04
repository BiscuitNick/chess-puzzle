#!/usr/bin/env python3
"""
Preprocess Lichess puzzle database for chess puzzle game.

Downloads, filters, validates, and exports mate-in-N puzzles to SQLite.
"""

import argparse
import csv
import logging
import os
import re
import sqlite3
import subprocess
import sys
from pathlib import Path
from typing import Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Lichess puzzle database URL
PUZZLE_DB_URL = "https://database.lichess.org/lichess_db_puzzle.csv.zst"

# Mate themes we're interested in
MATE_THEMES = {
    'mateIn1': 1,
    'mateIn2': 2,
    'mateIn3': 3,
    'mateIn4': 4,
    'mateIn5': 5,
}


def download_puzzle_database(output_path: Path, force: bool = False) -> Path:
    """Download the Lichess puzzle database."""
    zst_path = output_path.with_suffix('.csv.zst')
    csv_path = output_path.with_suffix('.csv')

    if csv_path.exists() and not force:
        logger.info(f"Using existing CSV file: {csv_path}")
        return csv_path

    if not zst_path.exists() or force:
        logger.info(f"Downloading puzzle database from {PUZZLE_DB_URL}...")
        try:
            subprocess.run(
                ['curl', '-L', '-o', str(zst_path), PUZZLE_DB_URL],
                check=True
            )
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to download puzzle database: {e}")
            raise

    if zst_path.exists():
        logger.info(f"Decompressing {zst_path}...")
        try:
            subprocess.run(
                ['zstd', '-d', '-f', str(zst_path), '-o', str(csv_path)],
                check=True
            )
        except subprocess.CalledProcessError:
            # Try using Python zstandard library as fallback
            try:
                import zstandard as zstd
                logger.info("Using zstandard Python library for decompression...")
                with open(zst_path, 'rb') as compressed:
                    dctx = zstd.ZstdDecompressor()
                    with open(csv_path, 'wb') as output:
                        dctx.copy_stream(compressed, output)
            except ImportError:
                logger.error("zstd command not found and zstandard library not installed")
                raise

    return csv_path


def get_mate_depth(themes: str) -> Optional[int]:
    """Extract mate depth from puzzle themes."""
    for theme, depth in MATE_THEMES.items():
        if theme in themes:
            return depth
    return None


def validate_move_count(moves: str, mate_in: int) -> bool:
    """
    Validate that move count matches expected mate depth.

    For mate-in-N puzzles, the solution should have 2*N - 1 half-moves.
    This is because: player makes N moves, opponent makes N-1 responses.

    Example:
    - Mate in 1: 1 move (player checkmates)
    - Mate in 2: 3 moves (player, opponent, player checkmates)
    - Mate in 3: 5 moves (player, opponent, player, opponent, player checkmates)
    """
    move_list = moves.strip().split()
    expected_moves = 2 * mate_in - 1
    return len(move_list) == expected_moves


def create_database(db_path: Path) -> sqlite3.Connection:
    """Create SQLite database with puzzle schema."""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute('''
        CREATE TABLE IF NOT EXISTS puzzles (
            id TEXT PRIMARY KEY,
            fen TEXT NOT NULL,
            moves TEXT NOT NULL,
            rating INTEGER NOT NULL,
            themes TEXT,
            mate_in INTEGER
        )
    ''')

    cursor.execute('CREATE INDEX IF NOT EXISTS idx_rating ON puzzles(rating)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_mate_in ON puzzles(mate_in)')

    conn.commit()
    return conn


def process_puzzles(
    csv_path: Path,
    db_path: Path,
    max_mate_depth: int = 5,
    validate_depths: bool = True,
    max_puzzles: Optional[int] = None
) -> dict:
    """Process puzzles from CSV and insert into SQLite database."""
    stats = {
        'total_processed': 0,
        'filtered_non_mate': 0,
        'filtered_depth_exceeded': 0,
        'invalid_move_count': 0,
        'inserted': 0,
    }

    conn = create_database(db_path)
    cursor = conn.cursor()

    logger.info(f"Processing puzzles from {csv_path}...")

    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)

        # Skip header if present
        first_row = next(reader)
        if first_row[0].lower() == 'puzzleid':
            logger.info("Skipping CSV header row")
        else:
            # First row is data, process it
            reader = [first_row] + list(reader)
            reader = iter(reader)

        batch = []
        batch_size = 10000

        for row in reader:
            stats['total_processed'] += 1

            if max_puzzles and stats['total_processed'] > max_puzzles:
                break

            if len(row) < 8:
                continue

            puzzle_id = row[0]
            fen = row[1]
            moves = row[2]
            rating = int(row[3])
            themes = row[7] if len(row) > 7 else ''

            # Check for mate theme
            mate_depth = get_mate_depth(themes)
            if mate_depth is None:
                stats['filtered_non_mate'] += 1
                continue

            # Check mate depth limit
            if mate_depth > max_mate_depth:
                stats['filtered_depth_exceeded'] += 1
                continue

            # Validate move count
            if validate_depths and not validate_move_count(moves, mate_depth):
                stats['invalid_move_count'] += 1
                continue

            batch.append((puzzle_id, fen, moves, rating, themes, mate_depth))

            if len(batch) >= batch_size:
                cursor.executemany(
                    'INSERT OR REPLACE INTO puzzles VALUES (?, ?, ?, ?, ?, ?)',
                    batch
                )
                conn.commit()
                stats['inserted'] += len(batch)
                logger.info(f"Processed {stats['total_processed']:,} puzzles, inserted {stats['inserted']:,}")
                batch = []

        # Insert remaining batch
        if batch:
            cursor.executemany(
                'INSERT OR REPLACE INTO puzzles VALUES (?, ?, ?, ?, ?, ?)',
                batch
            )
            conn.commit()
            stats['inserted'] += len(batch)

    conn.close()
    return stats


def main():
    parser = argparse.ArgumentParser(
        description='Preprocess Lichess puzzles for chess puzzle game'
    )
    parser.add_argument(
        '--input', '-i',
        type=Path,
        help='Path to input CSV file (will download if not provided)'
    )
    parser.add_argument(
        '--output', '-o',
        type=Path,
        default=Path('data/puzzles.db'),
        help='Output SQLite database path (default: data/puzzles.db)'
    )
    parser.add_argument(
        '--max-mate-depth', '-m',
        type=int,
        default=5,
        help='Maximum mate depth to include (default: 5)'
    )
    parser.add_argument(
        '--validate-depths',
        action='store_true',
        default=True,
        help='Validate move counts match mate depth (default: True)'
    )
    parser.add_argument(
        '--no-validate-depths',
        action='store_false',
        dest='validate_depths',
        help='Skip move count validation'
    )
    parser.add_argument(
        '--max-puzzles',
        type=int,
        help='Maximum number of puzzles to process (for testing)'
    )
    parser.add_argument(
        '--force-download',
        action='store_true',
        help='Force re-download of puzzle database'
    )

    args = parser.parse_args()

    # Ensure output directory exists
    args.output.parent.mkdir(parents=True, exist_ok=True)

    # Get input CSV path
    if args.input and args.input.exists():
        csv_path = args.input
    else:
        # Download puzzle database
        csv_path = download_puzzle_database(
            args.input or Path('data/lichess_puzzles'),
            force=args.force_download
        )

    # Process puzzles
    stats = process_puzzles(
        csv_path=csv_path,
        db_path=args.output,
        max_mate_depth=args.max_mate_depth,
        validate_depths=args.validate_depths,
        max_puzzles=args.max_puzzles
    )

    # Print statistics
    logger.info("\n=== Processing Statistics ===")
    logger.info(f"Total processed:        {stats['total_processed']:,}")
    logger.info(f"Filtered (non-mate):    {stats['filtered_non_mate']:,}")
    logger.info(f"Filtered (depth > {args.max_mate_depth}):   {stats['filtered_depth_exceeded']:,}")
    logger.info(f"Invalid move count:     {stats['invalid_move_count']:,}")
    logger.info(f"Inserted to database:   {stats['inserted']:,}")
    logger.info(f"\nDatabase saved to: {args.output}")


if __name__ == '__main__':
    main()
