FROM ubuntu:22.04
SHELL ["/bin/bash", "-c"]
RUN apt update
# Install necessary tooling
RUN apt install -y git qemu-user qemu-system-arm wget sudo build-essential python3-pip cmake swig time gcc-arm-none-eabi gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu unzip
# Setup non-root user
RUN useradd -ms /bin/bash -G sudo ubuntu
RUN passwd -d ubuntu
USER ubuntu
WORKDIR /home/ubuntu
# Fetching repositories as zips; could use git clone as well
RUN wget https://github.com/slothy-optimizer/slothy/archive/refs/heads/main.zip -O slothy.zip
RUN wget https://github.com/slothy-optimizer/pqmx/archive/refs/heads/ches2024_artifact.zip -O pqmx.zip
RUN wget https://github.com/slothy-optimizer/pqax/archive/refs/heads/ches2024_artifact.zip -O pqax.zip
RUN unzip slothy.zip
RUN rm slothy.zip
RUN mv slothy-ches2024_artifact slothy
RUN unzip pqax.zip
RUN rm pqax.zip
RUN mv pqax-ches2024_artifact pqax
RUN unzip pqmx.zip
RUN rm pqmx.zip
RUN mv pqmx-ches2024_artifact pqmx
# Python prerequisite for OR-Tools
RUN python3 -m pip install mypy-protobuf
ENV PATH="${PATH}:/home/ubuntu/.local/bin"
ENV PYTHONPATH /home/ubuntu/
# Build OR-Tools
WORKDIR /home/ubuntu/slothy/submodules
RUN rm -rf ./or-tools
RUN wget https://github.com/google/or-tools/archive/refs/tags/v9.7.zip -O or-tools.zip
RUN unzip or-tools.zip
RUN rm or-tools.zip
RUN mv or-tools-9.7 or-tools
WORKDIR /home/ubuntu/slothy/submodules/or-tools
COPY 0001-Pin-pybind11_protobuf-commit-in-cmake-files.patch .
RUN git apply 0001-Pin-pybind11_protobuf-commit-in-cmake-files.patch
RUN mkdir /home/ubuntu/slothy/submodules/or-tools/build
RUN cmake -S. -Bbuild -DBUILD_PYTHON:BOOL=ON -DBUILD_SAMPLES:BOOL=OFF -DBUILD_EXAMPLES:BOOL=OFF
WORKDIR /home/ubuntu/slothy/submodules/or-tools/build
RUN make -j8
WORKDIR /home/ubuntu/slothy
RUN /home/ubuntu/slothy/submodules/or-tools/build/python/venv/bin/python3 -m pip install sympy
# Setup symlinks from slothy repository to pqmx and pqax
RUN rm -rf /home/ubuntu/pqax/slothy
RUN ln -s /home/ubuntu/slothy /home/ubuntu/pqax/slothy
RUN rm -rf /home/ubuntu/pqmx/slothy
RUN ln -s /home/ubuntu/slothy /home/ubuntu/pqmx/slothy
WORKDIR /home/ubuntu
RUN ln -s /home/ubuntu/slothy/paper/README.md /home/ubuntu/README.md
