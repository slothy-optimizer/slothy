FROM ubuntu:22.04
SHELL ["/bin/bash", "-c"]
RUN apt update
# Install necessary tooling
RUN apt-get install -y qemu-user qemu-system-arm wget sudo build-essential python3-pip time gcc-arm-none-eabi gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu unzip
# Setup non-root user
RUN useradd -ms /bin/bash -G sudo ubuntu
RUN passwd -d ubuntu
USER ubuntu
WORKDIR /home/ubuntu
# Fetching repositories as zips; could use git clone as well
RUN wget https://github.com/slothy-optimizer/slothy/archive/refs/heads/ches2024_artifact.zip -O slothy.zip
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
# Build OR-Tools
WORKDIR /home/ubuntu/slothy
RUN python3 -m pip install -r requirements.txt
# Setup symlinks from slothy repository to pqmx and pqax
RUN rm -rf /home/ubuntu/pqax/slothy
RUN ln -s /home/ubuntu/slothy /home/ubuntu/pqax/slothy
RUN rm -rf /home/ubuntu/pqmx/slothy
RUN ln -s /home/ubuntu/slothy /home/ubuntu/pqmx/slothy
WORKDIR /home/ubuntu
RUN ln -s /home/ubuntu/slothy/paper/README.md /home/ubuntu/README.md
