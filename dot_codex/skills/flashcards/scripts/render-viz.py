"""Run user-supplied Python code that produces a PNG, saved at OUT_PATH.

Usage:
    render-viz.py <out.png>  <stdin: python source>

Conventions for the user code:
- The variable `OUT_PATH` (str) is bound before exec — write your figure there.
- Matplotlib: `plt.savefig(OUT_PATH, dpi=160, bbox_inches="tight",
                            facecolor="#1a1b26", edgecolor="none")`
  If the user code calls `plt.show()` instead of saving, this script falls
  back to saving the active figure automatically.
- Plotly: `fig.write_image(OUT_PATH, width=900, height=600, scale=2)`
  (requires `kaleido`, already installed by setup-env.sh).
- graphviz: `Digraph(...).render(OUT_PATH.removesuffix(".png"), format="png",
                                  cleanup=True)`.
- Anything else: write the PNG bytes to OUT_PATH yourself.

The script verifies OUT_PATH exists after exec and exits non-zero otherwise.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path


def _fallback_matplotlib_save(out_path: str) -> bool:
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        return False
    if not plt.get_fignums():
        return False
    plt.gcf().savefig(
        out_path,
        dpi=160,
        bbox_inches="tight",
        facecolor="#1a1b26",
        edgecolor="none",
    )
    return True


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        sys.stderr.write("usage: render-viz.py <out.png>\n")
        return 2
    out_path = os.path.abspath(argv[1])
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)

    code = sys.stdin.read()
    if not code.strip():
        sys.stderr.write("error: empty stdin (expected python source)\n")
        return 2

    ns: dict[str, object] = {
        "OUT_PATH": out_path,
        "__name__": "__main__",
        "__file__": "<render-viz>",
    }
    exec(compile(code, "<render-viz>", "exec"), ns)

    if not os.path.exists(out_path):
        if not _fallback_matplotlib_save(out_path):
            sys.stderr.write(
                "error: code finished but no file at " + out_path + "\n"
            )
            return 1

    size = os.path.getsize(out_path)
    print(f"✓ wrote {out_path} ({size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
