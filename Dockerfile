FROM rust:1.44.1-slim-buster

RUN apt-get update \
  && apt-get install -y --no-install-recommends clang=1:7.* cmake=3.* \
     libsnappy-dev=1.* \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

ARG USER_ID
ARG GROUP_ID

RUN addgroup --gid $GROUP_ID user
RUN adduser --disabled-login --system --shell /bin/false --uid $USER_ID --gid $GROUP_ID user

USER user
WORKDIR /home/user
COPY ./ /home/user

RUN cargo install --path .

# Electrum RPC
EXPOSE 50001

# Prometheus monitoring
EXPOSE 4224

STOPSIGNAL SIGINT

