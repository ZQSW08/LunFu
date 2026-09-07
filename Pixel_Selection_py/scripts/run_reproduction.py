"""运行论文 Pixel Selection 的合成等价复现。"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from pixel_selection.pipeline import run_reproduction  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the paper reproduction pipeline")
    parser.add_argument("--output-root", default=str(ROOT / "outputs"), help="输出目录")
    parser.add_argument("--frames", type=int, default=300, help="合成视频帧数")
    args = parser.parse_args()
    result = run_reproduction(args.output_root, frames=args.frames)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
