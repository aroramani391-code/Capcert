# Reproducible environment for the CAPCert artifact.
#
#   docker build -t capcert-artifact .
#   docker run --rm -it capcert-artifact make verify
#
# The image carries the pinned Python stack and a Rust toolchain for
# rust/lfr.  It does not carry Ghidra or any malware corpus: the first is a
# licensed download and the second is not redistributable.  See
# docs/REAL_DATA.md for wiring both in.

FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential curl ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

# Rust 1.79 for rust/lfr
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain 1.79.0 --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /artifact
COPY requirements.txt VERSIONS.lock ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN cd rust/lfr && cargo build --release --quiet && cargo test --quiet

# Smoke test at build time: if the verification suite cannot run, the image is
# not worth shipping.
RUN python verification/tv3_smt.py --quick --results /tmp/build-check \
    && rm -rf /tmp/build-check

CMD ["make", "demo"]
