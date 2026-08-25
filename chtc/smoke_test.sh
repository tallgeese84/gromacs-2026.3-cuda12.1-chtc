#!/usr/bin/env bash
set -Eeuo pipefail

echo "===== CHTC GROMACS CONTAINER SMOKE TEST ====="
echo "Host: $(hostname)"
echo "Started: $(date --iso-8601=seconds)"
echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"

test -n "${CUDA_VISIBLE_DEVICES:-}" || {
    echo "ERROR: HTCondor did not assign a visible GPU." >&2
    exit 2
}

echo
echo "===== ASSIGNED GPU ====="
nvidia-smi --query-gpu=name,uuid,memory.total,driver_version --format=csv,noheader

echo
echo "===== GROMACS BUILD ====="
gmx --version | tee gromacs_version.txt
grep -Eq '^GROMACS version:[[:space:]]+2026\.3$' gromacs_version.txt
grep -Eq '^GPU support:[[:space:]]+CUDA$' gromacs_version.txt
gmx mdrun -h >/dev/null

echo
echo "CHTC_GROMACS_CONTAINER_SMOKE_TEST_PASS"
echo "Finished: $(date --iso-8601=seconds)"
