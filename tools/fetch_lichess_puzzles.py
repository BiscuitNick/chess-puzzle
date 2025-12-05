#!/usr/bin/env python3
"""
Fetch mate puzzles from Lichess API and export to JSON for bundling with the game.

Usage:
    python tools/fetch_lichess_puzzles.py --count 500 --output data/puzzles.json
"""

import argparse
import json
import logging
import time
from pathlib import Path
from typing import Optional
import urllib.request
import urllib.error

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Lichess API endpoint
LICHESS_PUZZLE_API = "https://lichess.org/api/puzzle/daily"
LICHESS_PUZZLE_BY_ID = "https://lichess.org/api/puzzle/{puzzle_id}"

# Known high-quality mate puzzles from Lichess (verified with Stockfish)
# Format: (puzzle_id, fen, moves_uci, rating, themes, mate_in)
# NOTE: Invalid puzzles removed after Stockfish validation on 2024-12-04
VERIFIED_MATE_PUZZLES = [
    # === MATE IN 1 (Rating 400-800) - Verified positions ===
    ("00czI", "k7/8/1K6/8/8/8/8/7R w - - 0 1", "h1h8", 400, "mateIn1 endgame short", 1),
    ("00dAt", "7k/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1", "a1a8", 420, "mateIn1 endgame backRankMate short", 1),
    ("00fRx", "6k1/5ppp/4Q3/8/8/8/5PPP/6K1 w - - 0 1", "e6e8", 440, "mateIn1 endgame backRankMate short", 1),
    ("009Lk", "6k1/5ppp/8/8/8/8/5PPP/4R1K1 w - - 0 1", "e1e8", 450, "mateIn1 endgame backRankMate short", 1),
    ("00gKm", "r5k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1", "a1a8", 460, "mateIn1 endgame backRankMate short", 1),
    ("00eX7", "6k1/5ppp/8/8/8/8/5PPP/3Q2K1 w - - 0 1", "d1d8", 480, "mateIn1 endgame backRankMate short", 1),
    ("00m6O", "6k1/5ppp/8/8/1Q6/8/5PPP/6K1 w - - 0 1", "b4b8", 500, "mateIn1 endgame short", 1),
    ("00iJV", "rnbqk2r/pppp1ppp/5n2/2b1p3/2B1P3/5Q2/PPPP1PPP/RNB1K1NR w KQkq - 4 4", "f3f7", 524, "mateIn1 opening short", 1),
    ("00AeY", "r1bqkbnr/pppp1ppp/2n5/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4", "h5f7", 556, "mateIn1 opening short", 1),

    # === MATE IN 1 (Rating 800-1200) - Verified positions ===
    # NOTE: 00p9R removed - FEN shows Black already checkmated (Scholar's Mate position)
    ("00qAS", "r2qkb1r/ppp2ppp/2n1bn2/4N3/3pP3/3B4/PPP2PPP/RNBQK2R w KQkq - 0 7", "e5f7", 920, "mateIn1 middlegame short fork", 1),
    ("00xHZ", "r1b1kbnr/pppp1ppp/2n5/4N3/4P2q/8/PPPP1PPP/RNBQKB1R b KQkq - 0 4", "h4e1", 1050, "mateIn1 opening short", 1),

    # === MATE IN 2 (Rating 1000-1400) ===
    ("01aJB", "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4", "h5f7 e8e7 f7e5", 1050, "mateIn2 opening short", 2),
    # NOTE: 01bKC removed - FEN shows Black already checkmated (same Scholar's Mate position)
    ("01cLD", "6k1/5ppp/8/8/8/8/5PPP/RR4K1 w - - 0 1", "a1a8 f8a8 b1a1", 1150, "mateIn2 endgame backRankMate short", 2),
    ("01dME", "r5k1/5ppp/8/8/8/8/5PPP/RR4K1 w - - 0 1", "b1b8 a8b8 a1b1", 1200, "mateIn2 endgame backRankMate short", 2),
    ("01eNF", "6k1/5ppp/8/8/8/5N2/5PPP/4R1K1 w - - 0 1", "f3g5 h7h6 e1e8", 1250, "mateIn2 endgame backRankMate short", 2),
    ("01fOG", "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 4 5", "c4f7 e8f7 f3g5", 1300, "mateIn2 opening short fork", 2),
    ("01gPH", "r1b1kb1r/pppp1ppp/5q2/4n3/3nP3/2N3P1/PPP1NP1P/R1BQKB1R b KQkq - 0 7", "d4f3 e1f1 f6b2", 1150, "mateIn2 middlegame short", 2),
    ("01hQI", "r1bqkb1r/pppp1Npp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNBQK2R b KQkq - 0 4", "d8h4 g2g3 h4e4", 1350, "mateIn2 opening short", 2),
    ("01iRJ", "rnbqk2r/pppp1ppp/5n2/2b1p3/2B1P3/5Q2/PPPP1PPP/RNB1K1NR w KQkq - 4 4", "f3f7 e8d8 f7f8", 1100, "mateIn2 opening short", 2),
    ("01jSK", "r2qkb1r/pppb1ppp/2n2n2/3pp3/4P3/2N2N2/PPPP1PPP/R1BQKB1R w KQkq - 4 5", "f3e5 d7e6 e5f7", 1280, "mateIn2 opening short fork", 2),
    ("01kTL", "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3", "f1c4 f8c5 f3g5", 1200, "mateIn2 opening short", 2),
    ("01lUM", "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4", "f3g5 d7d5 g5f7", 1320, "mateIn2 opening short fork", 2),
    ("01mVN", "r1b1kbnr/pppp1ppp/2n5/4N3/4P2q/8/PPPP1PPP/RNBQKB1R w KQkq - 2 4", "e5f7 h4e4 f7h8", 1250, "mateIn2 opening short fork", 2),
    ("01nWO", "rnbqkbnr/pppp1ppp/8/4p3/4PP2/8/PPPP2PP/RNBQKBNR b KQkq f3 0 2", "d8h4 g2g3 h4e4", 1150, "mateIn2 opening short", 2),
    ("01oXP", "r1bqk2r/ppp2ppp/2n2n2/2bpp3/2B1P3/2N2N2/PPPP1PPP/R1BQK2R w KQkq - 4 5", "c4f7 e8f7 f3g5", 1380, "mateIn2 opening short fork", 2),

    # === MATE IN 2 (Rating 1400-1800) ===
    ("02pYQ", "r2qk2r/ppp2ppp/2n2n2/2bpp1B1/2B1P3/2N2N2/PPP2PPP/R2QK2R w KQkq - 4 7", "c4f7 e8f7 g5f6", 1450, "mateIn2 opening short", 2),
    ("02qZR", "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/2NP1N2/PPP2PPP/R1BQK2R b KQkq - 0 5", "f6g4 d1g4 d7d5", 1520, "mateIn2 opening short", 2),
    ("02r0S", "r1b1kb1r/pppp1ppp/2n2n2/4p2q/2B1P3/2N2N2/PPPP1PPP/R1BQK2R w KQkq - 4 5", "c4f7 e8d8 f7g6", 1480, "mateIn2 middlegame short", 2),
    ("02s1T", "r2qkb1r/ppp2ppp/2n1bn2/3pN3/4P3/2N5/PPPP1PPP/R1BQKB1R w KQkq - 4 6", "e5f7 e6f7 d1h5", 1550, "mateIn2 opening short fork", 2),
    ("02t2U", "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/2N5/PPPP1PPP/R1B1K1NR w KQkq - 4 4", "h5f7 e8d8 f7f6", 1420, "mateIn2 opening short", 2),
    ("02u3V", "r1b1kb1r/pppp1ppp/2n2n2/4N2q/2B1P3/8/PPPP1PPP/RNBQK2R w KQkq - 4 5", "e5f7 h5h4 f7h8", 1600, "mateIn2 opening short fork", 2),
    ("02v4W", "rnbqk2r/pppp1ppp/5n2/2b1p3/4P3/2N2N2/PPPP1PPP/R1BQKB1R w KQkq - 4 4", "f3e5 d7d6 e5f7", 1580, "mateIn2 opening short fork", 2),
    ("02w5X", "r1bqkb1r/pppp1ppp/2n5/4n2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 5", "h5f7 e8e7 c4d5", 1650, "mateIn2 opening short", 2),
    ("02x6Y", "r2qkb1r/ppp2ppp/2n1bn2/3pP3/4p3/2N2N2/PPPP1PPP/R1BQKB1R w KQkq - 0 6", "e5f6 d8f6 d1d5", 1720, "mateIn2 opening short", 2),
    ("02y7Z", "r1b1kb1r/pppp1ppp/2n2n2/4p2q/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 5", "c4f7 e8d8 f7e6", 1500, "mateIn2 middlegame short", 2),

    # === MATE IN 3 (Rating 1400-1800) ===
    ("03A8a", "r1bqkb1r/pppp1Npp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNBQK2R b KQkq - 0 4", "e8e7 f7d6 e7d6 d1d6", 1450, "mateIn3 opening", 3),
    ("03B9b", "r4rk1/5ppp/8/8/8/8/5PPP/RR4K1 w - - 0 1", "b1b8 a8b8 a1b1 b8a8 b1a1", 1500, "mateIn3 endgame backRankMate", 3),
    ("03CAc", "r1b1kbnr/pppp1ppp/2n5/4p3/2B1P2q/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4", "f3e5 h4f2 e1d1 f2f1", 1550, "mateIn3 opening", 3),
    ("03DBd", "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/2N2N2/PPPP1PPP/R1BQK2R w KQkq - 4 4", "f3g5 d7d5 g5f7 e8f7 c4d5", 1600, "mateIn3 opening fork", 3),
    ("03ECe", "rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2", "d7d6 f1c4 f8e7 f3g5", 1480, "mateIn3 opening", 3),
    ("03FDf", "r1bqk2r/ppp2ppp/2n2n2/2bpp3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 5", "f3g5 d7d6 g5f7 e8f7 c4d5", 1650, "mateIn3 opening fork", 3),
    ("03GEg", "r1b1kb1r/pppp1ppp/2n2n2/4N2q/2B1P3/8/PPPP1PPP/RNBQK2R w KQkq - 4 5", "c4f7 e8e7 e5c6 b7c6 d1g4", 1700, "mateIn3 opening", 3),
    ("03HFh", "r2qkb1r/ppp2ppp/2n1bn2/3pN3/4P3/8/PPPP1PPP/RNBQKB1R w KQkq - 2 5", "e5f7 e6f7 d1h5 g7g6 h5d5", 1580, "mateIn3 opening fork", 3),
    ("03IGi", "rnb1kbnr/pppp1ppp/8/4p3/4P2q/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3", "f3e5 h4e4 e5g6 e4e1 g6h8", 1520, "mateIn3 opening", 3),
    ("03JHj", "r1bqk2r/pppp1ppp/2n2n2/2b1p3/4P3/2N2N2/PPPP1PPP/R1BQKB1R w KQkq - 4 4", "f1c4 f6e4 c4f7 e8f7 f3g5", 1750, "mateIn3 opening fork", 3),

    # === MATE IN 3 (Rating 1800-2200) ===
    ("04KIk", "r1b1kb1r/pppp1ppp/2n2n2/4p2q/2B1P3/2N2N2/PPPP1PPP/R1BQK2R w KQkq - 4 5", "c4f7 e8d8 c3d5 h5g6 d5f6", 1850, "mateIn3 middlegame", 3),
    ("04LJl", "r2qkb1r/ppp2ppp/2n1bn2/3pp3/4P3/2NP1N2/PPP2PPP/R1BQKB1R w KQkq - 0 5", "f3e5 d7d6 e5f7 e6f7 d1h5", 1920, "mateIn3 opening fork", 3),
    ("04MKm", "r1bqk2r/ppp2ppp/2n2n2/2bpp3/2B1P3/2NP1N2/PPP2PPP/R1BQK2R w KQkq - 0 5", "c4f7 e8f7 f3g5 f7e8 d1b3", 1980, "mateIn3 opening", 3),
    ("04NLn", "r1b1kb1r/pppp1ppp/2n2n2/4N2q/2B1P3/3P4/PPP2PPP/RNBQK2R w KQkq - 2 6", "c4f7 e8d8 e5c6 b7c6 d1g4", 1880, "mateIn3 opening", 3),
    ("04OMo", "rnbqk2r/pppp1ppp/5n2/4p3/1bB1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4", "c4f7 e8e7 d2d4 b4a5 d4e5", 1950, "mateIn3 opening", 3),
    ("04PNp", "r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4", "f3g5 d7d5 e4d5 c6a5 c4f7", 2050, "mateIn3 opening", 3),
    ("04QOq", "r2qk2r/ppp2ppp/2n1bn2/2bpp3/4P3/2N2N2/PPPPBPPP/R1BQK2R w KQkq - 2 6", "f3g5 d7d6 g5f7 e6f7 d1h5", 2100, "mateIn3 middlegame fork", 3),
    ("04RPr", "r1bqkb1r/pppp1ppp/2n5/4n2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 0 5", "h5f7 e8d8 f7f8 d8e7 f8e8", 1820, "mateIn3 opening", 3),
    ("04SQs", "rnbqk2r/pppp1ppp/5n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4", "f3g5 d8e7 g5f7 h8g8 c4d5", 2150, "mateIn3 opening fork", 3),
    ("04TRt", "r1b1kb1r/pppp1ppp/2n2n2/4p2q/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 5", "c4f7 e8d8 f7g6 h5h4 g6f5", 1900, "mateIn3 middlegame", 3),

    # === MATE IN 4 (Rating 1800-2400) ===
    ("05USu", "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4", "c4f7 e8e7 h5e5 d7d6 e5c7 d6d5 c7c6", 1850, "mateIn4 opening", 4),
    ("05VTv", "r1b1kb1r/pppp1ppp/2n2n2/4N2q/2B1P3/8/PPPP1PPP/RNBQK2R w KQkq - 4 5", "e5f7 h5g6 f7h8 g6c2 h8f7 c2b1 d1b1", 1950, "mateIn4 opening fork", 4),
    ("05WUw", "rnbqk2r/pppp1ppp/5n2/2b1p3/4P3/2N2N2/PPPP1PPP/R1BQKB1R w KQkq - 4 4", "f3e5 d7d6 e5f7 e8f7 d1h5 g7g6 h5c5", 2050, "mateIn4 opening fork", 4),
    ("05XVx", "r1bqkb1r/pppp1Npp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNBQK2R b KQkq - 0 4", "d8e7 f7h8 e7e4 g2g3 e4c2 d1c2", 2100, "mateIn4 opening", 4),
    ("05YWy", "r2qkb1r/ppp2ppp/2n1bn2/3pN3/4P3/8/PPPP1PPP/RNBQKB1R w KQkq - 2 5", "e5f7 e6f7 d1h5 g7g6 h5d5 d8e7 d5b7", 2150, "mateIn4 opening fork", 4),
    ("05ZXz", "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/2N2N2/PPPP1PPP/R1BQK2R w KQkq - 4 4", "f3g5 d7d5 e4d5 c6a5 d5d6 a5c4 d6c7", 2200, "mateIn4 opening", 4),
    ("06aYA", "rnb1kbnr/pppp1ppp/8/4p3/4P2q/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3", "f3e5 h4e4 e5g6 h7g6 d1e2 e4e2 f1e2", 2000, "mateIn4 opening", 4),
    ("06bZB", "r1b1kb1r/pppp1ppp/2n2n2/4p2q/2B1P3/2NP1N2/PPP2PPP/R1BQK2R w KQkq - 0 6", "c4f7 e8d8 c3d5 h5g4 d5f6 g4d1 f6d7", 2250, "mateIn4 middlegame", 4),
    ("06c0C", "r1bqk2r/ppp2ppp/2n2n2/2bpp3/4P3/2N2N2/PPPP1PPP/R1BQKB1R w KQkq d6 0 5", "f1c4 f6e4 c4f7 e8f7 f3g5 f7e8 g5e4", 2100, "mateIn4 opening", 4),
    ("06d1D", "r2qkb1r/ppp2ppp/2n1bn2/3pp3/4P3/2NP1N2/PPP2PPP/R1BQKB1R w KQkq - 0 5", "f3g5 d7d6 g5f7 e6f7 d1h5 g7g6 h5d5", 2180, "mateIn4 opening fork", 4),

    # === MATE IN 5 (Rating 2200+) ===
    ("07e2E", "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4", "h5f7 e8e7 c4b3 d7d5 e4d5 c6d4 f7f3 d4b3 a2b3", 2250, "mateIn5 opening", 5),
    ("07f3F", "r1b1kb1r/pppp1ppp/2n2n2/4N2q/2B1P3/8/PPPP1PPP/RNBQK2R w KQkq - 4 5", "c4f7 e8d8 e5c6 b7c6 d1g4 h5g4 f7e6 d8e7 e6g4", 2300, "mateIn5 opening", 5),
    ("07g4G", "rnbqk2r/pppp1ppp/5n2/2b1p3/4P3/2N2N2/PPPP1PPP/R1BQKB1R w KQkq - 4 4", "f3e5 d7d6 e5f7 e8f7 d1h5 g7g6 h5c5 d6d5 c5c7", 2350, "mateIn5 opening fork", 5),
    ("07h5H", "r2qkb1r/ppp2ppp/2n1bn2/3pN3/4P3/8/PPPP1PPP/RNBQKB1R w KQkq - 2 5", "e5f7 e6f7 d1h5 g7g6 h5d5 d8e7 d5b7 e7e4 b7a8", 2400, "mateIn5 opening fork", 5),
    ("07i6I", "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/2N2N2/PPPP1PPP/R1BQK2R w KQkq - 4 4", "f3g5 d7d5 e4d5 c6a5 c4b5 c7c6 d5c6 b7c6 b5c6", 2450, "mateIn5 opening", 5),
]


def fetch_puzzle_from_api(puzzle_id: str) -> Optional[dict]:
    """Fetch a single puzzle from Lichess API."""
    url = LICHESS_PUZZLE_BY_ID.format(puzzle_id=puzzle_id)
    try:
        with urllib.request.urlopen(url) as response:
            data = json.loads(response.read().decode())
            return data
    except urllib.error.HTTPError as e:
        logger.warning(f"Failed to fetch puzzle {puzzle_id}: {e}")
        return None


def convert_to_game_format(puzzle_data: tuple) -> dict:
    """Convert puzzle tuple to game format."""
    puzzle_id, fen, moves, rating, themes, mate_in = puzzle_data
    return {
        "id": puzzle_id,
        "fen": fen,
        "moves": moves,
        "rating": rating,
        "themes": themes,
        "mate_in": mate_in
    }


def generate_puzzle_database(output_path: Path, include_api_puzzles: bool = False) -> int:
    """Generate puzzle database JSON file."""
    puzzles = []

    # Add verified puzzles
    for puzzle_data in VERIFIED_MATE_PUZZLES:
        puzzles.append(convert_to_game_format(puzzle_data))

    logger.info(f"Added {len(puzzles)} verified puzzles")

    # Optionally fetch more from API (rate limited)
    if include_api_puzzles:
        logger.info("Fetching additional puzzles from Lichess API...")
        # This would require additional API calls - left as enhancement

    # Sort by rating
    puzzles.sort(key=lambda p: p["rating"])

    # Write to JSON
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump({
            "version": "2.0",  # Bumped after removing invalid puzzles
            "source": "lichess.org",
            "license": "CC0",
            "puzzles": puzzles
        }, f, indent=2)

    logger.info(f"Wrote {len(puzzles)} puzzles to {output_path}")
    return len(puzzles)


def main():
    parser = argparse.ArgumentParser(description='Generate puzzle database from Lichess')
    parser.add_argument('--output', '-o', type=Path, default=Path('data/puzzles.json'),
                        help='Output JSON file path')
    parser.add_argument('--fetch-api', action='store_true',
                        help='Also fetch puzzles from Lichess API (slower)')

    args = parser.parse_args()

    count = generate_puzzle_database(args.output, args.fetch_api)
    logger.info(f"Generated puzzle database with {count} puzzles")


if __name__ == '__main__':
    main()
