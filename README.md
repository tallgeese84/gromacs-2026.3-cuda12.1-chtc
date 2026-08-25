# GROMACS 2026.3 + CUDA 12.1 for CHTC

This repository builds a public `linux/amd64` container for single-GPU
GROMACS production jobs on the UW-Madison Center for High Throughput Computing
(CHTC).

Image name:

```text
ghcr.io/tallgeese84/gromacs-2026.3-cuda12.1-chtc
```

## What is pinned

- GROMACS 2026.3 source archive and SHA-256
- NVIDIA CUDA 12.1.1 `devel` base, the version family currently recommended by
  CHTC for GPU Lab integration
- CMake 3.31.5 binary archive and SHA-256
- Linux x86-64 build
- CUDA targets 8.0, 8.6, 8.9, and 9.0 (A100, RTX A6000, L40/L40S, and
  H100/H200)
- thread-MPI, OpenMP, mixed precision, and AVX2-256

The image is deliberately not an MPI/multi-GPU build. The RPA production
workflow assigns one model and one GPU to each HTCondor job.

## Build and publish

1. Create a public GitHub repository named
   `gromacs-2026.3-cuda12.1-chtc` under `tallgeese84`.
2. Add these files to the repository's `main` branch.
3. The push triggers `.github/workflows/build-and-publish.yml`.
4. Open the repository's **Actions** tab and watch **Build and publish GROMACS
   container**.
5. After the first successful build, open the new package from the repository
   page, choose **Package settings**, and change its visibility to **Public**.
   GitHub Container Registry packages are private on first publication.
6. Download the workflow artifact `gromacs-container-digest`. It contains the
   immutable `ghcr.io/...@sha256:...` image reference that production jobs
   should use.

The `edge` tag is convenient for the first smoke test. Production submit files
must use the immutable digest, not `edge` or another mutable tag.

## CHTC smoke test

After the package is public, copy `chtc/smoke_test.sh` and
`chtc/smoke_test.sub` to a directory under your CHTC home and run:

```bash
chmod 700 smoke_test.sh
condor_submit smoke_test.sub
condor_watch_q
```

When it completes:

```bash
cat smoke_test_*.out
cat smoke_test_*.err
```

The expected final marker is:

```text
CHTC_GROMACS_CONTAINER_SMOKE_TEST_PASS
```

This smoke test proves that CHTC can pull the image, expose the assigned GPU,
load GROMACS, and load the CUDA-enabled `mdrun`. The existing 0.5-ns RPA
benchmark is still required before production because it measures real ns/day
and numerical execution with the actual TPR.

## Primary references

- [CHTC GPU jobs](https://chtc.cs.wisc.edu/uw-research-computing/gpu-jobs)
- [CHTC container jobs](https://chtc.cs.wisc.edu/uw-research-computing/docker-jobs)
- [GROMACS 2026.3 installation guide](https://manual.gromacs.org/documentation/current/install-guide/index.html)
- [GitHub container publishing](https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

## Important limitations

- The build itself runs on GitHub's CPU runner, so it verifies compilation and
  linkage but not GPU dynamics.
- The final image follows CHTC's current CUDA 12.1.1 recommendation. Re-check
  that recommendation before rebuilding far in the future.
- Do not replace the Stage 2F/Stage 3 TPR or checkpoint with files produced by
  an older GROMACS release.
