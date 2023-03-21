ARG BASE_IMAGE=ros:noetic



#
# SPDX-FileCopyrightText: Copyright (c) 1993-2022 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

ARG CUDA_VERSION=11.8.0
ARG OS_VERSION=18.04

FROM nvidia/cuda:${CUDA_VERSION}-cudnn8-devel-ubuntu${OS_VERSION}
LABEL maintainer="NVIDIA CORPORATION"

ENV TRT_VERSION 8.5.3.1
SHELL ["/bin/bash", "-c"]

# Setup user account
ARG uid=1000
ARG gid=1000
RUN groupadd -r -f -g ${gid} trtuser && useradd -o -r -l -u ${uid} -g ${gid} -ms /bin/bash trtuser
RUN usermod -aG sudo trtuser
RUN echo 'trtuser:nvidia' | chpasswd
RUN mkdir -p /workspace && chown trtuser /workspace

# Install requried libraries
RUN apt-get update && apt-get install -y software-properties-common
RUN add-apt-repository ppa:ubuntu-toolchain-r/test
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    wget \
    git \
    pkg-config \
    sudo \
    ssh \
    libssl-dev \
    pbzip2 \
    pv \
    bzip2 \
    unzip \
    devscripts \
    lintian \
    fakeroot \
    dh-make \
    build-essential

# Install python3
RUN apt-get install -y --no-install-recommends \
      python3 \
      python3-pip \
      python3-dev \
      python3-wheel &&\
    cd /usr/local/bin &&\
    ln -s /usr/bin/python3 python &&\
    ln -s /usr/bin/pip3 pip;

# Install TensorRT
RUN if [ "${CUDA_VERSION}" = "10.2" ] ; then \
    v="${TRT_VERSION%.*}-1+cuda${CUDA_VERSION}" &&\
    apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/3bf863cc.pub &&\
    apt-get update &&\
    sudo apt-get install libnvinfer8=${v} libnvonnxparsers8=${v} libnvparsers8=${v} libnvinfer-plugin8=${v} \
        libnvinfer-dev=${v} libnvonnxparsers-dev=${v} libnvparsers-dev=${v} libnvinfer-plugin-dev=${v} \
        python3-libnvinfer=${v}; \
else \
    v="${TRT_VERSION%.*}-1+cuda${CUDA_VERSION%.*}" &&\
    apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/3bf863cc.pub &&\
    apt-get update &&\
    sudo apt-get install libnvinfer8=${v} libnvonnxparsers8=${v} libnvparsers8=${v} libnvinfer-plugin8=${v} \
        libnvinfer-dev=${v} libnvonnxparsers-dev=${v} libnvparsers-dev=${v} libnvinfer-plugin-dev=${v} \
        python3-libnvinfer=${v}; \
fi 

# Install PyPI packages
RUN pip3 install --upgrade pip
RUN pip3 install setuptools>=41.0.0
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install -r /tmp/requirements.txt
RUN pip3 install jupyter jupyterlab
# Workaround to remove numpy installed with tensorflow
RUN pip3 install --upgrade numpy

# Install Cmake
RUN cd /tmp && \
    wget https://github.com/Kitware/CMake/releases/download/v3.14.4/cmake-3.14.4-Linux-x86_64.sh && \
    chmod +x cmake-3.14.4-Linux-x86_64.sh && \
    ./cmake-3.14.4-Linux-x86_64.sh --prefix=/usr/local --exclude-subdir --skip-license && \
    rm ./cmake-3.14.4-Linux-x86_64.sh

# Download NGC client
RUN cd /usr/local/bin && wget https://ngc.nvidia.com/downloads/ngccli_cat_linux.zip && unzip ngccli_cat_linux.zip && chmod u+x ngc-cli/ngc && rm ngccli_cat_linux.zip ngc-cli.md5 && echo "no-apikey\nascii\n" | ngc-cli/ngc config set

# Set environment and working directory
ENV TRT_LIBPATH /usr/lib/x86_64-linux-gnu
ENV TRT_OSSPATH /workspace/TensorRT
ENV PATH="${PATH}:/usr/local/bin/ngc-cli"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${TRT_OSSPATH}/build/out:${TRT_LIBPATH}"
WORKDIR /workspace

USER trtuser
RUN ["/bin/bash"]

FROM maven AS xsdcache

# install schema-fetcher
RUN microdnf install git && \
    git clone --depth=1 https://github.com/mfalaize/schema-fetcher.git && \
    cd schema-fetcher && \
    mvn install

# fetch XSD file for package.xml
RUN mkdir -p /opt/xsd/package.xml && \
    java -jar schema-fetcher/target/schema-fetcher-1.0.0-SNAPSHOT.jar /opt/xsd/package.xml http://download.ros.org/schema/package_format2.xsd

# fetch XSD file for roslaunch
RUN mkdir -p /opt/xsd/roslaunch && \
    java -jar schema-fetcher/target/schema-fetcher-1.0.0-SNAPSHOT.jar /opt/xsd/roslaunch https://gist.githubusercontent.com/nalt/dfa2abc9d2e3ae4feb82ca5608090387/raw/roslaunch.xsd

# fetch XSD files for SDF
RUN mkdir -p /opt/xsd/sdf && \
    java -jar schema-fetcher/target/schema-fetcher-1.0.0-SNAPSHOT.jar /opt/xsd/sdf http://sdformat.org/schemas/root.xsd && \
    sed -i 's|http://sdformat.org/schemas/||g' /opt/xsd/sdf/*

# fetch XSD file for URDF
RUN mkdir -p /opt/xsd/urdf && \
    java -jar schema-fetcher/target/schema-fetcher-1.0.0-SNAPSHOT.jar /opt/xsd/urdf https://raw.githubusercontent.com/devrt/urdfdom/xsd-with-xacro/xsd/urdf.xsd

FROM $BASE_IMAGE

MAINTAINER Yosuke Matsusaka <yosuke.matsusaka@gmail.com>

SHELL ["/bin/bash", "-c"]

ENV DEBIAN_FRONTEND noninteractive

# workaround to enable bash completion for apt-get
# see: https://github.com/tianon/docker-brew-ubuntu-core/issues/75
RUN rm /etc/apt/apt.conf.d/docker-clean

# use closest mirror for apt updates
RUN sed -i -e 's/http:\/\/archive/mirror:\/\/mirrors/' -e 's/http:\/\/security/mirror:\/\/mirrors/' -e 's/\/ubuntu\//\/mirrors.txt/' /etc/apt/sources.list

RUN apt-get update || true && \
    apt-get install -y curl apt-transport-https ca-certificates && \
    apt-get clean

# need to renew the key for some reason
RUN curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add -

# OSRF distribution is better for gazebo
RUN sh -c 'echo "deb http://packages.osrfoundation.org/gazebo/ubuntu-stable `lsb_release -cs` main" > /etc/apt/sources.list.d/gazebo-stable.list' && \
    curl -L http://packages.osrfoundation.org/gazebo.key | apt-key add -

# nice to have nodejs for web goodies
RUN sh -c 'echo "deb https://deb.nodesource.com/node_12.x `lsb_release -cs` main" > /etc/apt/sources.list.d/nodesource.list' && \
    curl -sSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -

# install depending packages
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y bash-completion less wget vim-tiny iputils-ping net-tools openssh-client git openjdk-8-jdk-headless nodejs sudo imagemagick byzanz python-dev libsecret-1-dev && \
    npm install -g yarn && \
    apt-get clean

# basic python packages
RUN if [ $(lsb_release -cs) = "focal" ]; then \
        apt-get install -y python-is-python3; \
        curl -kL https://bootstrap.pypa.io/get-pip.py | python; \
    else \
        curl -kL https://bootstrap.pypa.io/pip/2.7/get-pip.py | python; \
    fi && \
    pip install --upgrade --ignore-installed --no-cache-dir pyassimp pylint==1.9.4 autopep8 python-language-server[all] notebook~=5.7 Pygments matplotlib ipywidgets jupyter_contrib_nbextensions nbimporter supervisor supervisor_twiddler argcomplete

# jupyter extensions
RUN jupyter nbextension enable --py widgetsnbextension && \
    jupyter contrib nbextension install --system

# add non-root user
RUN useradd -m developer && \
    echo developer ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/developer && \
    chmod 0440 /etc/sudoers.d/developer

# install depending packages (install moveit! algorithms on the workspace side, since moveit-commander loads it from the workspace)
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y ros-$ROS_DISTRO-desktop ros-$ROS_DISTRO-moveit ros-$ROS_DISTRO-moveit-commander ros-$ROS_DISTRO-moveit-ros-visualization ros-$ROS_DISTRO-trac-ik ros-$ROS_DISTRO-move-base-msgs ros-$ROS_DISTRO-ros-numpy && \
    apt-get clean

# install bio_ik
RUN source /opt/ros/$ROS_DISTRO/setup.bash && \
    mkdir -p /bio_ik_ws/src && \
    cd /bio_ik_ws/src && \
    catkin_init_workspace && \
    git clone --depth=1 https://github.com/TAMS-Group/bio_ik.git && \
    cd .. && \
    catkin_make install -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/ros/$ROS_DISTRO -DCATKIN_ENABLE_TESTING=0 && \
    cd / && rm -r /bio_ik_ws

# configure services
RUN mkdir -p /etc/supervisor/conf.d
COPY .devcontainer/supervisord.conf /etc/supervisor/supervisord.conf
COPY .devcontainer/theia.conf /etc/supervisor/conf.d/theia.conf
COPY .devcontainer/jupyter.conf /etc/supervisor/conf.d/jupyter.conf

COPY .devcontainer/entrypoint.sh /entrypoint.sh

COPY .devcontainer/sim.py /usr/bin/sim

COPY --from=xsdcache /opt/xsd /opt/xsd

USER developer
WORKDIR /home/developer

ENV HOME /home/developer
ENV SHELL /bin/bash

# jre is required to use XML editor extension
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64

# colorize less
RUN echo "export LESS='-R'" >> ~/.bash_profile && \
    echo "export LESSOPEN='|pygmentize -g %s'" >> ~/.bash_profile

# enable bash completion
RUN git clone --depth=1 https://github.com/Bash-it/bash-it.git ~/.bash_it && \
    ~/.bash_it/install.sh --silent && \
    rm ~/.bashrc.bak && \
    echo "source /usr/share/bash-completion/bash_completion" >> ~/.bashrc && \
    bash -i -c "bash-it enable completion git"

RUN echo 'eval "$(register-python-argcomplete sim)"' >> ~/.bashrc

RUN git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && \
    ~/.fzf/install --all

RUN git clone --depth 1 https://github.com/b4b4r07/enhancd.git ~/.enhancd && \
    echo "source ~/.enhancd/init.sh" >> ~/.bashrc

# init rosdep
RUN rosdep update

# global vscode config
ADD .vscode /home/developer/.vscode
ADD .vscode /home/developer/.theia
ADD .devcontainer/compile_flags.txt /home/developer/compile_flags.txt
ADD .devcontainer/templates /home/developer/templates
RUN sudo chown -R developer:developer /home/developer

# install theia web IDE
COPY .devcontainer/theia-latest.package.json /home/developer/package.json
RUN yarn --cache-folder ./ycache && rm -rf ./ycache && \
    NODE_OPTIONS="--max_old_space_size=4096" yarn theia build && \
    yarn theia download:plugins

ENV THEIA_DEFAULT_PLUGINS local-dir:/home/developer/plugins

# enable jupyter extensions
RUN jupyter nbextension enable hinterland/hinterland && \
    jupyter nbextension enable toc2/main && \
    jupyter nbextension enable code_prettify/autopep8 && \
    jupyter nbextension enable nbTranslate/main && \
    mkdir -p /home/developer/.ipython/profile_default && \
    echo "c.Completer.use_jedi = False" >> /home/developer/.ipython/profile_default/ipython_kernel_config.py

# enter ROS world
RUN echo "source /opt/ros/$ROS_DISTRO/setup.bash" >> ~/.bashrc

EXPOSE 3000 8888

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "sudo", "-E", "/usr/local/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
