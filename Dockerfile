# renovate: datasource=npm depName=renovate versioning=npm
ARG RENOVATE_VERSION=25.19.2

# Base image
#============
FROM renovate/buildpack:5@sha256:5520467fb0aea16c8b404fcf10a08ac9a3dbe57cffbe6a8b5ba3e71a05dcfc63 AS base

LABEL name="renovate"
LABEL org.opencontainers.image.source="https://github.com/renovatebot/renovate" \
  org.opencontainers.image.url="https://renovatebot.com" \
  org.opencontainers.image.licenses="AGPL-3.0-only"

# renovate: datasource=docker versioning=docker
RUN install-tool node 14.21.3

# renovate: datasource=npm versioning=npm
RUN install-tool yarn 1.22.19

WORKDIR /usr/src/app

# Build image
#============
FROM base as tsbuild

# use buildin python to faster build
RUN install-apt build-essential python3
RUN npm install -g yarn-deduplicate

COPY package.json .
COPY yarn.lock .

RUN yarn install --frozen-lockfile

COPY tsconfig.json .
COPY tsconfig.app.json .
COPY src src

RUN set -ex; \
  yarn build; \
  chmod +x dist/*.js;

ARG RENOVATE_VERSION
RUN npm --no-git-tag-version version ${RENOVATE_VERSION}
RUN yarn add renovate@${RENOVATE_VERSION}
RUN yarn-deduplicate --strategy highest
RUN yarn install --frozen-lockfile --production

# check is re2 is usable
RUN node -e "new require('re2')('.*').exec('test')"


# Final image
#============
FROM base as final

# renovate: datasource=docker versioning=docker
RUN install-tool docker 20.10.24

ENV RENOVATE_BINARY_SOURCE=docker

COPY --from=tsbuild /usr/src/app/package.json package.json
COPY --from=tsbuild /usr/src/app/dist dist
COPY --from=tsbuild /usr/src/app/node_modules node_modules

# exec helper
COPY bin/ /usr/local/bin/
RUN ln -sf /usr/src/app/dist/renovate.js /usr/local/bin/renovate;
RUN ln -sf /usr/src/app/dist/config-validator.js /usr/local/bin/renovate-config-validator;
CMD ["renovate"]

ARG RENOVATE_VERSION

RUN renovate --version;

LABEL org.opencontainers.image.version="${RENOVATE_VERSION}"

# Numeric user ID for the ubuntu user. Used to indicate a non-root user to OpenShift
USER 1000
