# syntax=docker/dockerfile:1

FROM nvidia/cuda:12.1.1-devel-ubuntu22.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG CMAKE_VERSION=3.31.5
ARG CMAKE_SHA256=2984e70515ff60c5e4a41922b5d715a8168a696a89721e3b114e36f453244f72
ARG GROMACS_VERSION=2026.3
ARG GROMACS_SHA256=1094b7bbc6a3960223827114626657110b40096cdf9598a727935fc84ebf8aa0

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      curl \
      libhwloc-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/build

# Ubuntu 22.04's CMake is older than GROMACS 2026.3 requires. Install a
# checksum-pinned Kitware binary release rather than using an unpinned PPA.
RUN curl --fail --location --retry 5 --retry-all-errors \
      --output cmake.tar.gz \
      "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz" \
 && printf '%s  %s\n' "${CMAKE_SHA256}" cmake.tar.gz | sha256sum --check --strict - \
 && mkdir -p /opt/cmake \
 && tar --extract --gzip --file cmake.tar.gz --strip-components=1 --directory /opt/cmake \
 && /opt/cmake/bin/cmake --version

ENV PATH="/opt/cmake/bin:${PATH}"

RUN curl --fail --location --retry 5 --retry-all-errors \
      --output gromacs.tar.gz \
      "https://ftp.gromacs.org/gromacs/gromacs-${GROMACS_VERSION}.tar.gz" \
 && printf '%s  %s\n' "${GROMACS_SHA256}" gromacs.tar.gz | sha256sum --check --strict - \
 && tar --extract --gzip --file gromacs.tar.gz \
 && cmake -S "gromacs-${GROMACS_VERSION}" -B gromacs-build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/opt/gromacs \
      -DCMAKE_CUDA_ARCHITECTURES="80;86;89;90" \
      -DGMX_BUILD_OWN_FFTW=ON \
      -DGMX_BUILD_UNITTESTS=OFF \
      -DGMX_GPU=CUDA \
      -DGMX_MPI=OFF \
      -DGMX_OPENMP=ON \
      -DGMX_SIMD=AVX2_256 \
      -DGMX_THREAD_MPI=ON \
      -DREGRESSIONTEST_DOWNLOAD=OFF \
 && cmake --build gromacs-build --parallel \
 && cmake --install gromacs-build \
 && rm -rf /tmp/build/*

# CHTC currently recommends a final image based on a CUDA tag beginning with
# 12.1.1-devel for GPU Lab compatibility. The second stage omits build-only OS
# packages while retaining that tested CUDA base.
FROM nvidia/cuda:12.1.1-devel-ubuntu22.04 AS runtime

ARG DEBIAN_FRONTEND=noninteractive
ARG GROMACS_VERSION=2026.3

LABEL org.opencontainers.image.title="GROMACS 2026.3 CUDA 12.1 for CHTC" \
      org.opencontainers.image.description="Single-GPU, thread-MPI GROMACS 2026.3 build for CHTC A100, L40/L40S, H100, and H200 workers" \
      org.opencontainers.image.source="https://github.com/tallgeese84/gromacs-2026.3-cuda12.1-chtc" \
      org.opencontainers.image.version="${GROMACS_VERSION}"

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      libgomp1 \
      libhwloc15 \
      python3 \
      zstd \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/gromacs /opt/gromacs

ENV PATH="/opt/gromacs/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/gromacs/lib:${LD_LIBRARY_PATH}" \
    OMP_DYNAMIC="FALSE"

RUN gmx --version | tee /opt/gromacs/BUILD_INFO.txt \
 && grep -Eq '^GROMACS version:[[:space:]]+2026\.3$' /opt/gromacs/BUILD_INFO.txt \
 && grep -Eq '^GPU support:[[:space:]]+CUDA$' /opt/gromacs/BUILD_INFO.txt \
 && gmx mdrun -h >/dev/null

WORKDIR /work

CMD ["gmx", "--version"]
