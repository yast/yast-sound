FROM registry.opensuse.org/yast/head/containers/yast-cpp:latest
RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends \
  alsa-devel \
  kernel-default \
  yast2 \
  yast2-ruby-bindings \
  yast2-testsuite
COPY . /usr/src/app

