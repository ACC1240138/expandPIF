#!/usr/bin/env python
"""Execute one notebook in a fresh kernel and log wall time for every code cell."""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import re
import sys
import time
import traceback
from datetime import datetime
from pathlib import Path
from typing import Any

import nbformat
from nbclient import NotebookClient


LABEL_PATTERN = re.compile(r"^#\|\s*label:\s*([^\r\n]+)", re.MULTILINE)


def now_iso() -> str:
    """Return a timezone-aware local timestamp."""
    return datetime.now().astimezone().isoformat(timespec="seconds")


def available_memory_bytes() -> int | None:
    """Return available physical memory when psutil is installed."""
    try:
        import psutil  # type: ignore

        return int(psutil.virtual_memory().available)
    except Exception:
        return None


def atomic_write_json(path: Path, payload: dict[str, Any]) -> None:
    """Write JSON atomically so remote readers never observe a partial file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    replace_with_retry(temporary, path)


def atomic_write_notebook(path: Path, notebook: Any) -> None:
    """Persist the notebook atomically after each executed code cell."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    nbformat.write(notebook, temporary)
    replace_with_retry(temporary, path)


def replace_with_retry(source: Path, destination: Path, attempts: int = 20) -> None:
    """Replace a file, tolerating short Windows locks from readers or scanners."""
    last_error: PermissionError | None = None
    for attempt in range(attempts):
        try:
            os.replace(source, destination)
            return
        except PermissionError as error:
            last_error = error
            time.sleep(min(0.25 * (attempt + 1), 2.0))
    if last_error is not None:
        raise last_error


def append_jsonl(path: Path, payload: dict[str, Any]) -> None:
    """Append and flush one durable timing event."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(payload, ensure_ascii=False) + "\n")
        handle.flush()
        os.fsync(handle.fileno())


def cell_label(cell: Any, cell_index: int) -> str:
    """Read the Quarto label or create a stable fallback label."""
    match = LABEL_PATTERN.search(str(cell.get("source", "")))
    return match.group(1).strip() if match else f"unlabelled-cell-{cell_index}"


class LoggedNotebookClient(NotebookClient):
    """NotebookClient that saves and logs after every completed code cell."""

    def __init__(
        self,
        *args: Any,
        notebook_path: Path,
        events_path: Path,
        progress_path: Path,
        run_id: str,
        **kwargs: Any,
    ) -> None:
        super().__init__(*args, **kwargs)
        self.notebook_path = notebook_path
        self.events_path = events_path
        self.progress_path = progress_path
        self.run_id = run_id
        self.code_total = sum(
            1
            for cell in self.nb.cells
            if cell.get("cell_type") == "code" and str(cell.get("source", "")).strip()
        )
        self.code_completed = 0

    def write_progress(self, **updates: Any) -> None:
        payload: dict[str, Any] = {
            "run_id": self.run_id,
            "pid": os.getpid(),
            "notebook": self.notebook_path.name,
            "notebook_path": str(self.notebook_path.resolve()),
            "code_cells_total": self.code_total,
            "code_cells_completed": self.code_completed,
            "available_memory_bytes": available_memory_bytes(),
            "updated_at": now_iso(),
        }
        payload.update(updates)
        atomic_write_json(self.progress_path, payload)

    async def async_execute_cell(
        self,
        cell: Any,
        cell_index: int,
        execution_count: int | None = None,
        store_history: bool = True,
    ) -> Any:
        is_code = cell.get("cell_type") == "code" and bool(str(cell.get("source", "")).strip())
        if not is_code:
            return await super().async_execute_cell(
                cell,
                cell_index,
                execution_count=execution_count,
                store_history=store_history,
            )

        label = cell_label(cell, cell_index)
        started_at = now_iso()
        started_monotonic = time.monotonic()
        self.write_progress(
            status="running",
            active_cell_index=cell_index,
            active_label=label,
            active_started_at=started_at,
        )
        print(
            json.dumps(
                {
                    "event": "cell_start",
                    "notebook": self.notebook_path.name,
                    "cell_index": cell_index,
                    "label": label,
                    "started_at": started_at,
                },
                ensure_ascii=False,
            ),
            flush=True,
        )

        try:
            result = await super().async_execute_cell(
                cell,
                cell_index,
                execution_count=execution_count,
                store_history=store_history,
            )
        except Exception as error:
            ended_at = now_iso()
            elapsed_seconds = time.monotonic() - started_monotonic
            event = {
                "run_id": self.run_id,
                "notebook": self.notebook_path.name,
                "cell_index": cell_index,
                "cell_id": cell.get("id"),
                "label": label,
                "started_at": started_at,
                "ended_at": ended_at,
                "elapsed_seconds": elapsed_seconds,
                "elapsed_minutes": elapsed_seconds / 60.0,
                "status": "failed",
                "execution_count": cell.get("execution_count"),
                "error_type": type(error).__name__,
                "error": str(error),
            }
            append_jsonl(self.events_path, event)
            atomic_write_notebook(self.notebook_path, self.nb)
            self.write_progress(
                status="failed",
                active_cell_index=cell_index,
                active_label=label,
                failed_at=ended_at,
                error_type=type(error).__name__,
                error=str(error),
            )
            print(json.dumps(event, ensure_ascii=False), flush=True)
            raise

        ended_at = now_iso()
        elapsed_seconds = time.monotonic() - started_monotonic
        self.code_completed += 1
        event = {
            "run_id": self.run_id,
            "notebook": self.notebook_path.name,
            "cell_index": cell_index,
            "cell_id": cell.get("id"),
            "label": label,
            "started_at": started_at,
            "ended_at": ended_at,
            "elapsed_seconds": elapsed_seconds,
            "elapsed_minutes": elapsed_seconds / 60.0,
            "status": "completed",
            "execution_count": cell.get("execution_count"),
        }
        append_jsonl(self.events_path, event)
        atomic_write_notebook(self.notebook_path, self.nb)
        self.write_progress(
            status="running",
            last_completed_cell_index=cell_index,
            last_completed_label=label,
            last_completed_at=ended_at,
            last_elapsed_seconds=elapsed_seconds,
            active_cell_index=None,
            active_label=None,
        )
        print(json.dumps(event, ensure_ascii=False), flush=True)
        return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--notebook", required=True, type=Path)
    parser.add_argument("--cwd", required=True, type=Path)
    parser.add_argument("--kernel", default="ir44")
    parser.add_argument("--events", required=True, type=Path)
    parser.add_argument("--progress", required=True, type=Path)
    parser.add_argument("--result", required=True, type=Path)
    parser.add_argument("--run-id", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    notebook_path = args.notebook.resolve()
    cwd = args.cwd.resolve()
    if not notebook_path.is_file():
        raise FileNotFoundError(f"Notebook not found: {notebook_path}")
    if not cwd.is_dir():
        raise NotADirectoryError(f"Execution directory not found: {cwd}")

    notebook = nbformat.read(notebook_path, as_version=4)
    for cell in notebook.cells:
        if cell.get("cell_type") == "code":
            cell["outputs"] = []
            cell["execution_count"] = None
            cell.setdefault("metadata", {}).pop("execution", None)
    atomic_write_notebook(notebook_path, notebook)

    client = LoggedNotebookClient(
        notebook,
        notebook_path=notebook_path,
        events_path=args.events.resolve(),
        progress_path=args.progress.resolve(),
        run_id=args.run_id,
        kernel_name=args.kernel,
        timeout=None,
        allow_errors=False,
        force_raise_errors=True,
        record_timing=True,
        shutdown_kernel="immediate",
    )
    started_at = now_iso()
    client.write_progress(status="starting", started_at=started_at)
    try:
        client.execute(cwd=str(cwd))
        code_cells = [
            cell
            for cell in notebook.cells
            if cell.get("cell_type") == "code" and str(cell.get("source", "")).strip()
        ]
        if not code_cells or code_cells[-1].get("execution_count") is None:
            raise RuntimeError("The final code cell has no execution_count after execution.")
        atomic_write_notebook(notebook_path, notebook)
        result = {
            "run_id": args.run_id,
            "status": "completed",
            "notebook": notebook_path.name,
            "notebook_path": str(notebook_path),
            "started_at": started_at,
            "ended_at": now_iso(),
            "code_cells_total": client.code_total,
            "code_cells_completed": client.code_completed,
            "final_label": cell_label(code_cells[-1], len(notebook.cells) - 1),
            "final_execution_count": code_cells[-1].get("execution_count"),
        }
        atomic_write_json(args.result.resolve(), result)
        client.write_progress(**result)
        print(json.dumps(result, ensure_ascii=False), flush=True)
        return 0
    except Exception as error:
        result = {
            "run_id": args.run_id,
            "status": "failed",
            "notebook": notebook_path.name,
            "notebook_path": str(notebook_path),
            "started_at": started_at,
            "ended_at": now_iso(),
            "error_type": type(error).__name__,
            "error": str(error),
            "traceback": traceback.format_exc(),
        }
        atomic_write_json(args.result.resolve(), result)
        client.write_progress(**result)
        print(json.dumps(result, ensure_ascii=False), file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    if sys.platform == "win32":
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
    raise SystemExit(main())
