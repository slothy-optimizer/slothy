#!/usr/bin/env sh

git submodule init
git submodule update

cd or-tools
mkdir build
cmake -S. -Bbuild -DBUILD_PYTHON:BOOL=ON
cd build
make -j8

source python/venv/bin/activate
pip3 install sympy
deactivate
