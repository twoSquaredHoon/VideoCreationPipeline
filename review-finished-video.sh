#!/usr/bin/env bash
# Medical review for end-product videos (.mp4 / .mov).
set -euo pipefail
cd "$(dirname "$0")"

if [[ $# -lt 1 ]]; then
  echo "Usage:"
  echo "  ./review-finished-video.sh --video PATH [--project-dir PROJECT]"
  echo "  ./review-finished-video.sh --all-inbox"
  echo ""
  echo "Inbox: output/end-products/inbox/"
  echo "Passed: output/end-products/passed/YYYY-MM-DD/"
  exit 1
fi

if [[ "${1:-}" == "--all-inbox" ]]; then
  exec .venv/bin/python scripts/review_end_product.py \
    --inbox output/end-products/inbox \
    --archive-passed \
    --passed-root output/end-products/passed
fi

exec .venv/bin/python scripts/review_end_product.py \
  --archive-passed \
  --passed-root output/end-products/passed \
  "$@"
