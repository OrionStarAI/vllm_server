###########################
# Base Image Build
###########################
FROM nvidia/cuda:12.1.0-devel-ubuntu22.04 AS dev
LABEL maintainer huangyi@orionstar.com

RUN sed -i s@/archive.ubuntu.com/@/mirrors.aliyun.com/@g /etc/apt/sources.list
RUN sed -i s@/security.ubuntu.com/@/mirrors.aliyun.com/@g /etc/apt/sources.list
RUN apt-get clean && apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential \
        python3-pip \
        git
RUN ldconfig /usr/local/cuda-12.1/compat/

WORKDIR /workspace
RUN git clone https://github.com/vllm-project/vllm.git
RUN pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
RUN pip install --no-cache-dir --upgrade -r vllm/requirements.txt
RUN pip install --no-cache-dir --upgrade -r vllm/requirements-dev.txt

###########################
# Extension Image Build
###########################
FROM dev AS build

# install build dependencies
RUN pip install --no-cache-dir --upgrade -r vllm/requirements-build.txt

# cuda arch list used by torch
ARG torch_cuda_arch_list='7.0 7.5 8.0 8.6 8.9 9.0+PTX'
ENV TORCH_CUDA_ARCH_LIST=${torch_cuda_arch_list}
# max jobs used by Ninja to build extensions
ARG max_jobs=2
ENV MAX_JOBS=${max_jobs}
# number of threads used by nvcc
ARG nvcc_threads=8
ENV NVCC_THREADS=$nvcc_threads
# make sure punica kernels are built (for LoRA)
ENV VLLM_INSTALL_PUNICA_KERNELS=1
RUN cd vllm && python3 setup.py build_ext --inplace

###########################
# Test Image
###########################
FROM dev AS test

# copy pytorch extensions separately to avoid having to rebuild
WORKDIR /vllm-workspace
# ADD is used to preserve directory structure
COPY --from=dev /workspace/vllm/ /vllm-workspace/
COPY --from=build /workspace/vllm/vllm/*.so /vllm-workspace/vllm/
# ignore build dependencies installation because we are using pre-complied extensions
RUN rm pyproject.toml
RUN VLLM_USE_PRECOMPILED=1 pip install . --verbose

###########################
# Runtime Base Image
###########################
FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04 AS vllm-base

RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN echo 'Asia/Shanghai' >/etc/timezone
RUN sed -i s@/archive.ubuntu.com/@/mirrors.aliyun.com/@g /etc/apt/sources.list
RUN sed -i s@/security.ubuntu.com/@/mirrors.aliyun.com/@g /etc/apt/sources.list
RUN apt-get update -y && apt-get install -y python3-pip

WORKDIR /workspace
COPY --from=dev /workspace/vllm/ /workspace/
RUN pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
RUN pip install --no-cache-dir --upgrade -r requirements.txt
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1

###########################
# OpenAI API Server
###########################
FROM vllm-base AS vllm-openai
# install additional dependencies for openai api server
RUN pip install accelerate

COPY --from=build /workspace/vllm/vllm/*.so /workspace/vllm/

ENTRYPOINT python -m vllm.entrypoints.openai.api_server --host=0.0.0.0 --port=9999 --model=/workspace/models/$MODEL_DIR --trust-remote-code --gpu-memory-utilization=0.8 --device=cuda --served-model-name=$MODEL_NAME
