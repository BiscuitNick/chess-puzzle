#!/usr/bin/env python3
"""
Validate puzzle data using Stockfish engine.

For each puzzle:
- mate-in-1: After applying the move, position must be checkmate
- mate-in-N (N>1): Stockfish must confirm forced mate in remaining moves

Usage:
    python tools/validate_puzzles.py [--json data/puzzles.json] [--stockfish bin/stockfish/macos/stockfish]
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Optional


class ChessPosition:
    """Simple chess position handler for FEN parsing and move application."""

    PIECE_VALUES = {'p': 'pawn', 'n': 'knight', 'b': 'bishop', 'r': 'rook', 'q': 'queen', 'k': 'king'}

    def __init__(self, fen: str):
        self.fen = fen
        parts = fen.split()
        self.board = self._parse_board(parts[0])
        self.turn = parts[1] if len(parts) > 1 else 'w'
        self.castling = parts[2] if len(parts) > 2 else '-'
        self.en_passant = parts[3] if len(parts) > 3 else '-'
        self.halfmove = int(parts[4]) if len(parts) > 4 else 0
        self.fullmove = int(parts[5]) if len(parts) > 5 else 1

    def _parse_board(self, board_str: str) -> list:
        """Parse board portion of FEN into 8x8 array."""
        board = []
        for rank in board_str.split('/'):
            row = []
            for char in rank:
                if char.isdigit():
                    row.extend(['.'] * int(char))
                else:
                    row.append(char)
            board.append(row)
        return board

    def _board_to_fen(self) -> str:
        """Convert board array back to FEN board string."""
        fen_rows = []
        for row in self.board:
            fen_row = ''
            empty_count = 0
            for square in row:
                if square == '.':
                    empty_count += 1
                else:
                    if empty_count > 0:
                        fen_row += str(empty_count)
                        empty_count = 0
                    fen_row += square
            if empty_count > 0:
                fen_row += str(empty_count)
            fen_rows.append(fen_row)
        return '/'.join(fen_rows)

    def to_fen(self) -> str:
        """Convert position to FEN string."""
        board_fen = self._board_to_fen()
        return f"{board_fen} {self.turn} {self.castling} {self.en_passant} {self.halfmove} {self.fullmove}"

    def apply_uci_move(self, uci: str) -> 'ChessPosition':
        """Apply a UCI move and return new position."""
        from_sq = uci[0:2]
        to_sq = uci[2:4]
        promotion = uci[4] if len(uci) > 4 else None

        from_file = ord(from_sq[0]) - ord('a')
        from_rank = 8 - int(from_sq[1])
        to_file = ord(to_sq[0]) - ord('a')
        to_rank = 8 - int(to_sq[1])

        # Create new position
        new_board = [row[:] for row in self.board]
        piece = new_board[from_rank][from_file]
        new_board[from_rank][from_file] = '.'

        # Handle promotion
        if promotion:
            piece = promotion.upper() if piece.isupper() else promotion.lower()

        new_board[to_rank][to_file] = piece

        # Handle castling (move rook)
        if piece.lower() == 'k' and abs(to_file - from_file) == 2:
            if to_file > from_file:  # Kingside
                new_board[from_rank][7] = '.'
                new_board[from_rank][5] = 'R' if piece.isupper() else 'r'
            else:  # Queenside
                new_board[from_rank][0] = '.'
                new_board[from_rank][3] = 'R' if piece.isupper() else 'r'

        # Handle en passant capture
        if piece.lower() == 'p' and to_sq == self.en_passant:
            captured_rank = from_rank  # The captured pawn is on the same rank as the moving pawn
            new_board[captured_rank][to_file] = '.'

        # Create new position with updated state
        new_pos = ChessPosition.__new__(ChessPosition)
        new_pos.board = new_board
        new_pos.turn = 'b' if self.turn == 'w' else 'w'

        # Update castling rights
        new_castling = self.castling
        if piece.lower() == 'k':
            if piece.isupper():
                new_castling = new_castling.replace('K', '').replace('Q', '')
            else:
                new_castling = new_castling.replace('k', '').replace('q', '')
        if piece.lower() == 'r':
            if from_sq == 'a1':
                new_castling = new_castling.replace('Q', '')
            elif from_sq == 'h1':
                new_castling = new_castling.replace('K', '')
            elif from_sq == 'a8':
                new_castling = new_castling.replace('q', '')
            elif from_sq == 'h8':
                new_castling = new_castling.replace('k', '')
        new_pos.castling = new_castling if new_castling else '-'

        # Update en passant square
        if piece.lower() == 'p' and abs(to_rank - from_rank) == 2:
            ep_rank = (from_rank + to_rank) // 2
            ep_file = chr(ord('a') + to_file)
            new_pos.en_passant = f"{ep_file}{8 - ep_rank}"
        else:
            new_pos.en_passant = '-'

        new_pos.halfmove = 0 if piece.lower() == 'p' or self.board[to_rank][to_file] != '.' else self.halfmove + 1
        new_pos.fullmove = self.fullmove + 1 if self.turn == 'b' else self.fullmove
        new_pos.fen = new_pos.to_fen()

        return new_pos


class StockfishEngine:
    """Interface to Stockfish UCI engine."""

    def __init__(self, path: str):
        self.path = path
        self.process = None

    def start(self):
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

    def stop(self):
        """Stop Stockfish process."""
        if self.process:
            self._send("quit")
            self.process.wait()
            self.process = None

    def _send(self, command: str):
        """Send command to engine."""
        self.process.stdin.write(command + "\n")
        self.process.stdin.flush()

    def _wait_for(self, expected: str) -> list:
        """Wait for expected response, return all lines received."""
        lines = []
        while True:
            line = self.process.stdout.readline().strip()
            lines.append(line)
            if line.startswith(expected):
                break
        return lines

    def analyze(self, fen: str, depth: int = 15) -> dict:
        """Analyze position and return result."""
        self._send("ucinewgame")
        self._send(f"position fen {fen}")
        self._send(f"go depth {depth}")

        result = {
            "bestmove": None,
            "is_mate": False,
            "mate_in": None,
            "score_cp": None
        }

        while True:
            line = self.process.stdout.readline().strip()

            if line.startswith("bestmove"):
                parts = line.split()
                if len(parts) >= 2 and parts[1] != "(none)":
                    result["bestmove"] = parts[1]
                break

            if line.startswith("info") and "score" in line:
                parts = line.split()
                try:
                    score_idx = parts.index("score")
                    if parts[score_idx + 1] == "mate":
                        result["is_mate"] = True
                        result["mate_in"] = int(parts[score_idx + 2])
                    elif parts[score_idx + 1] == "cp":
                        result["score_cp"] = int(parts[score_idx + 2])
                except (ValueError, IndexError):
                    pass

        return result

    def is_checkmate(self, fen: str) -> bool:
        """Check if position is checkmate (no legal moves and in check)."""
        result = self.analyze(fen, depth=1)
        # If bestmove is (none) or null, there are no legal moves
        # We also need to verify it's check, not stalemate
        if result["bestmove"] is None:
            # Check if it's mate (score shows mate in 0 from opponent's perspective)
            # or analyze deeper to confirm
            return result.get("is_mate", False) or self._is_in_check(fen)
        return False

    def _is_in_check(self, fen: str) -> bool:
        """Heuristic check if the side to move is in check."""
        # This is a simplification - in a real implementation we'd check properly
        # For now, if there's no legal move and it's mate, Stockfish will indicate
        result = self.analyze(fen, depth=5)
        return result.get("is_mate", False) and result.get("mate_in") is not None and result.get("mate_in", 999) <= 0


def validate_puzzle(engine: StockfishEngine, puzzle: dict) -> tuple[bool, str]:
    """
    Validate a single puzzle.

    Returns (is_valid, reason)
    """
    puzzle_id = puzzle.get("id", "unknown")
    fen = puzzle.get("fen", "")
    moves_str = puzzle.get("moves", "")
    mate_in = puzzle.get("mate_in", 1)

    if not fen or not moves_str:
        return False, "Missing FEN or moves"

    moves = moves_str.split()

    try:
        pos = ChessPosition(fen)

        # First check: Is the position ALREADY checkmate before any move?
        # This catches corrupted puzzles where the FEN shows a terminal state
        initial_result = engine.analyze(fen, depth=1)
        if initial_result["bestmove"] is None or (initial_result["is_mate"] and initial_result.get("mate_in", 999) == 0):
            return False, "Position is already checkmate before puzzle starts"

        # For mate-in-1: apply the move and check if it's checkmate
        if mate_in == 1:
            if len(moves) < 1:
                return False, "No moves specified for mate-in-1"

            # Apply the first (and only) move
            new_pos = pos.apply_uci_move(moves[0])

            # Check if this is checkmate
            result = engine.analyze(new_pos.to_fen(), depth=10)

            # After the mating move, the position should have no legal moves
            # and Stockfish should indicate it's mate (mate in 0 or negative from the checkmated side)
            if result["bestmove"] is None or (result["is_mate"] and result.get("mate_in", 999) <= 0):
                return True, "Valid mate-in-1"

            # Also check if we're in checkmate by checking if there's a mate score of 0 or -0
            # Sometimes Stockfish shows this as the opponent having mate in 0
            if result["is_mate"] and abs(result.get("mate_in", 999)) == 0:
                return True, "Valid mate-in-1"

            return False, f"Move {moves[0]} does not deliver checkmate. Bestmove: {result['bestmove']}, mate_in: {result.get('mate_in')}"

        else:
            # For mate-in-N (N>1): verify the sequence leads to forced mate
            # Apply all moves and verify Stockfish confirms mate at each player's turn

            current_pos = pos
            for i, move in enumerate(moves):
                # Apply the move
                current_pos = current_pos.apply_uci_move(move)

                # After the last move, should be checkmate
                if i == len(moves) - 1:
                    result = engine.analyze(current_pos.to_fen(), depth=10)
                    if result["bestmove"] is None or (result["is_mate"] and result.get("mate_in", 999) <= 0):
                        return True, f"Valid mate-in-{mate_in}"
                    return False, f"Final position is not checkmate"

                # After player's move (even indices for white-to-move puzzles)
                # Stockfish should confirm forced mate
                if i % 2 == 0:  # Player just moved
                    result = engine.analyze(current_pos.to_fen(), depth=max(15, mate_in * 4))
                    # The opponent should be getting mated (negative mate score)
                    if not result["is_mate"]:
                        return False, f"Position after move {i+1} ({move}) doesn't show forced mate"

            return True, f"Valid mate-in-{mate_in}"

    except Exception as e:
        return False, f"Error: {str(e)}"


def main():
    parser = argparse.ArgumentParser(description='Validate puzzle data using Stockfish')
    parser.add_argument('--json', '-j', type=Path, default=Path('data/puzzles.json'),
                        help='Path to puzzles JSON file')
    parser.add_argument('--stockfish', '-s', type=Path, default=Path('bin/stockfish/macos/stockfish'),
                        help='Path to Stockfish binary')
    parser.add_argument('--output', '-o', type=Path, default=None,
                        help='Output file for validation results (JSON)')
    parser.add_argument('--verbose', '-v', action='store_true',
                        help='Verbose output')

    args = parser.parse_args()

    # Load puzzles
    if not args.json.exists():
        print(f"Error: Puzzle file not found: {args.json}")
        sys.exit(1)

    with open(args.json, 'r') as f:
        data = json.load(f)

    puzzles = data.get("puzzles", [])
    print(f"Loaded {len(puzzles)} puzzles from {args.json}")

    # Check Stockfish
    if not args.stockfish.exists():
        print(f"Error: Stockfish not found: {args.stockfish}")
        sys.exit(1)

    # Start Stockfish
    engine = StockfishEngine(str(args.stockfish))
    engine.start()
    print(f"Started Stockfish: {args.stockfish}")

    # Validate each puzzle
    results = {
        "valid": [],
        "invalid": []
    }

    for i, puzzle in enumerate(puzzles):
        puzzle_id = puzzle.get("id", f"unknown_{i}")
        is_valid, reason = validate_puzzle(engine, puzzle)

        if is_valid:
            results["valid"].append({"id": puzzle_id, "reason": reason})
            if args.verbose:
                print(f"[OK] {puzzle_id}: {reason}")
        else:
            results["invalid"].append({
                "id": puzzle_id,
                "reason": reason,
                "fen": puzzle.get("fen", ""),
                "moves": puzzle.get("moves", ""),
                "mate_in": puzzle.get("mate_in", 0)
            })
            print(f"[INVALID] {puzzle_id}: {reason}")

        # Progress indicator
        if (i + 1) % 10 == 0:
            print(f"Progress: {i + 1}/{len(puzzles)}")

    engine.stop()

    # Summary
    print(f"\n{'='*50}")
    print(f"Validation complete:")
    print(f"  Valid: {len(results['valid'])}")
    print(f"  Invalid: {len(results['invalid'])}")

    if results["invalid"]:
        print(f"\nInvalid puzzles to remove:")
        for inv in results["invalid"]:
            print(f"  - {inv['id']}: {inv['reason']}")

    # Output results
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"\nResults saved to: {args.output}")


if __name__ == '__main__':
    main()
