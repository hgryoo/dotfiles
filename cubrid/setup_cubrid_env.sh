#!/usr/bin/env bash
set -e

echo ">>> Updating base system..."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install tzdata

echo ">>> Adding Ubuntu toolchain PPA..."
sudo apt-get install -y software-properties-common
sudo add-apt-repository ppa:ubuntu-toolchain-r/test -y
sudo apt-get update -y

echo ">>> Installing essential build tools..."
sudo apt-get install -y --no-install-recommends \
    build-essential \
    wget git curl cmake ninja-build flex bison m4 \
    pkg-config unzip libtool autoconf automake rpm \
    systemtap systemtap-sdt-dev libelf-dev \
    ncurses-dev openjdk-8-jdk

echo ">>> Installing GCC 10 toolchain..."
sudo apt-get install -y --no-install-recommends gcc-10 g++-10
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 100
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 100

echo ">>> Checking compiler versions..."
gcc --version
g++ --version

# ------------------------------------------------------------------------
# CMake (optional override if system version < 3.26)
# ------------------------------------------------------------------------
CMAKE_VERSION=3.26.3
if ! cmake --version | grep -q "$CMAKE_VERSION"; then
  echo ">>> Installing CMake $CMAKE_VERSION ..."
  curl -L https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-linux-x86_64.tar.gz \
    | sudo tar xzvf - -C /usr --strip-components=1
fi

# ------------------------------------------------------------------------
# Ninja (ensure correct version)
# ------------------------------------------------------------------------
NINJA_VERSION=1.11.1
if ! ninja --version | grep -q "$NINJA_VERSION"; then
  echo ">>> Installing Ninja $NINJA_VERSION ..."
  curl -L https://github.com/ninja-build/ninja/archive/refs/tags/v$NINJA_VERSION.tar.gz \
    | tar xzvf - && cd ninja-$NINJA_VERSION
  cmake -Bbuild && cmake --build build
  sudo mv build/ninja /usr/bin/ninja
  cd .. && rm -rf ninja-$NINJA_VERSION
fi

# ------------------------------------------------------------------------
# Bison (for parser)
# ------------------------------------------------------------------------
BISON_VERSION=3.8.2
if ! bison --version | grep -q "$BISON_VERSION"; then
  echo ">>> Installing Bison $BISON_VERSION ..."
  curl -L https://ftp.gnu.org/gnu/bison/bison-$BISON_VERSION.tar.gz \
    | tar xzvf - && cd bison-$BISON_VERSION
  ./configure --prefix=/usr && make -j$(nproc) && sudo make install
  cd .. && rm -rf bison-$BISON_VERSION
fi

# ------------------------------------------------------------------------
# Summary
# -------------------------------------------------------

echo
echo ">>> Environment summary:"
echo "GCC  : $(gcc --version | head -n1)"
echo "CMake: $(cmake --version | head -n1)"
echo "Ninja: $(ninja --version)"
echo "Java : $(java -version 2>&1 | head -n1)"
echo "Bison: $(bison --version | head -n1)"
echo "Flex : $(flex --version | head -n1)"
echo "SystemTap: $(systemtap --version | head -n1)"
echo
echo "✅ CUBRID build environment for Ubuntu 24.04 ready!"

