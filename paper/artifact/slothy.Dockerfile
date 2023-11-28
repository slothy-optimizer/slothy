FROM ubuntu:22.04
SHELL ["/bin/bash", "-c"]
RUN apt update
RUN apt install -y git sudo build-essential python3-pip cmake swig time gcc-arm-none-eabi gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu
RUN useradd -ms /bin/bash -G sudo ubuntu
RUN passwd -d ubuntu
USER ubuntu
WORKDIR /home/ubuntu
RUN git clone -b ches2024_artifact https://github.com/slothy-optimizer/pqax.git
RUN git clone -b ches2024_artifact https://github.com/slothy-optimizer/pqmx.git
RUN git clone -b ches2024_artifact https://github.com/slothy-optimizer/slothy.git
RUN python3 -m pip install mypy-protobuf
ENV PATH="${PATH}:/home/ubuntu/.local/bin"
ENV PYTHONPATH /home/ubuntu/
WORKDIR /home/ubuntu/slothy/submodules
RUN git submodule init
RUN git submodule update
WORKDIR /home/ubuntu/slothy/submodules/or-tools
RUN mkdir /home/ubuntu/slothy/submodules/or-tools/build
RUN cmake -S. -Bbuild -DBUILD_PYTHON:BOOL=ON -DBUILD_SAMPLES:BOOL=OFF -DBUILD_EXAMPLES:BOOL=OFF
WORKDIR /home/ubuntu/slothy/submodules/or-tools/build
RUN make -j8
WORKDIR /home/ubuntu/slothy
RUN /home/ubuntu/slothy/submodules/or-tools/build/python/venv/bin/python3 -m pip install sympy
