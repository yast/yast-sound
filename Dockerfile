FROM yastdevel/cpp:sle12-sp5


RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends \
  alsa-devel \
  kernel-default \
  yast2 \
  yast2-ruby-bindings \
  yast2-testsuite
COPY . /usr/src/app

