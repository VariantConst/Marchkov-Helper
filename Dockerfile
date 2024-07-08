FROM node:22-slim AS base

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

RUN corepack enable

COPY . /marchkov
WORKDIR /marchkov

RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install

RUN --mount=type=cache,id=apt,target=/var/cache/apt \
    apt-get update && apt-get install -y python3 python3-pip

EXPOSE 3000

VOLUME [ "/marchkov/.env.local" ]

CMD [ "pnpm", "run", "dev" ]
