<div align="center">
     <b>🌐English</b> | <a href="./README_zh.md">🇨🇳中文</a>
</div>


# Tables of Contents

- [🎯 Target](#aim)
- [👄 Description](#intro)
- [👣 Steps](#steps)

<a name="aim"></a><br>
# 1. Target

This project builds an LLM inference service image based on the vLLM inference framework using a Dockerfile, adhering to the OpenAI interface standards.  This facilitates users in launching a local LLM model inference service.

<a name="intro"></a><br>
# 2. Description

# 2.1. Inference Service Arch
\<Inference service by running a docker image\> --------API Call-------- \<Inference request by client\>

Inference steps：

1） \<Client\>   --------Send inference request-------->  \<Server\>

2） \<Client\>  <--------Send inference response--------  \<Server\>

# 2.2. Details

LLM, such as those provided by OpenAI, typically operate within a server-client software architecture. In this setup, the client initiates requests through an API, the server responds, and the client receives the reply. OpenAI's API interface is particularly versatile and widely used in this context.

OrionStar has developed a Docker image file designed to simplify the service startup process by eliminating the need for manual software environment setup, software build&installation, Python package installation, and service initiation. For those unfamiliar with Docker, it is recommended to familiarize yourself with it through the [Docker documentation link](https://docs.docker.com/reference/) and ensure Docker is installed locally. This article will not elaborate on that process.

The image is built on the Ubuntu 22.04 system and the Docker build steps include:

- Installing all necessary apt packages and Python PIP packages.

- Downloading the vLLM source code, building, and installing the vLLM package.

- Launching the vLLM's built-in inference service based on the OpenAI API.

# 2.3. Host Operating System

The host operating systems that have been tested primarily include:

- CentOS 7.9
- Ubuntu 20.04
- Windows

It is recommended to use Windows Subsystem for Linux (WSL) when operating on Windows host.


# 2.4. Environment Variables
Users need to prepare the model for inference in advance and understand the meaning of the following environment variables:

- **MODEL_ABSOLUTE_ROOT**

    The root directory where the model directory is located. This needs to be an absolute path and cannot be a symbolic link, otherwise, it will not be accessible inside the Docker Container. This variable is mainly reflected in the mapping between model root path on host and the model root path on container when the Docker image is started, that is, <span style="color:blue;">"-v \$MODEL_ABSOLUTE_ROOT:/workspace/models"</span>. Here, the left side of the colon represents the host machine's model root path, and the right side is a fixed path inside the Docker container. The Docker container will start and locate the model correctly based on /workspace/models combined with the model path.

    Example: If a user has downloaded the Orion-14B-Chat model to <span style="color:blue;">\$HOME/Downloads</span>, the complete local model path is <span style="color:blue;">\$HOME/Downloads/Orion-14B-Chat</span>, then MODEL_ABSOLUTE_ROOT would be <span style="color:blue;">\$HOME/Downloads</span>.

- **MODEL_DIR**

    The directory name of the model. For example: If a user has downloaded the Orion-14B-Chat model to <span style="color:blue;">\$HOME/Downloads</span>, the complete local model path is <span style="color:blue;">\$HOME/Downloads/Orion-14B-Chat</span>, then MODEL_DIR would be Orion-14B-Chat.

- **MODEL_NAME**

    The name of the model during the inference process. This name must be specified in the HTTP packet when initiating an inference request and must remain consistent with the name used when starting the inference service.

- **CUDA_VISIBLE_DEVICES**

    Users need to verify the GPU information in their work environment. This can be done by checking the current GPU usage with nvidia-smi and deciding how many cards to use for the inference service.


<a name="steps"></a><br>
# 3. Steps

## 3.1. Build Docker Image

The build speed, depends on the network speed and the performance of the host machine. It involves downloading PIP packages, which could take from 20 minutes to 60 minutes.

Please be patient, and if there are any errors, submit the error information through the GitHub issue system.

In this case, we will name the built Docker image as follows:
<span style="color:blue;">vllm_server:0.0.0.0</span>
```shell
git clone git@github.com:OrionStarAI/vllm_server.git
cd vllm_server
docker build -t vllm_server:0.0.0.0 -f Dockerfile .
```

## 3.2. Run Docker Image & Start Inference Service

The communication port used between the host and the Docker container is <span style="color:blue;">9999</span>. If it conflicts with the user's host machine port, please modify the setting for <span style="color:blue;">"--port"</span> in the <span style="color:blue;">ENTRYPOINT</span> section of the Dockerfile, as well as the port mapping relationship between the host machine and the container during the docker run startup process.

For environment variable <span style="color:blue;">\$MODEL_ABSOLUTE_ROOT</span>, please fill in the absolute path of the host machine. At this case, we'll use the download path <span style="color:blue;">\$HOME/Downloads</span> for illustration.
In this example, we assume the host has two graphics cards (0 and 1, which can be viewed using the nvidia-smi command) specified as <span style="color:blue;">"CUDA_VISIBLE_DEVICES=0,1"</span>. Additionally, when the container is launched, it will run the inference service using CUDA.

When multiple cards are used for inference, it is necessary to add the <span style="color:blue;">-tp <gpu_num></span> parameter to the vLLM service startup command.

For the model directory, we will use Orion-14B-Chat as an example, and the model name given to the inference service is orion14b-chat. The inference service is started using the previously built image named <span style="color:blue;">vllm_server:0.0.0.0</span>.

```shell
docker run --gpus all -it -p 9999:9999 -v $(pwd)/logs:/workspace/logs:rw -v $HOME/Downloads:/workspace/models -e CUDA_VISIBLE_DEVICES=0,1 -e MODEL_DIR=Orion-14B-Chat -e MODEL_NAME=orion14b-chat vllm_server:0.0.0.0
```

If the GPU memory is insufficient, it is recommended to use the quantized version of the model. For instance, with the self-developed Orion14B model by OrionStar, if the memory of a single GPU is less than 32GB, you can modify the code in the ENTRYPOINT section of the Dockerfile to start the inference service with the quantized model. (Note that here the MODEL_DIR should be the directory of the quantized version of the model, and remember to add the data type and quantization method parameters <span style="color:blue;">--dtype float16 --quantization awq</span>.)
```shell
python -m vllm.entrypoints.openai.api_server --host=0.0.0.0 --port=9999 --model=/workspace/models/$MODEL_DIR --dtype float16 --quantization awq --trust-remote-code --gpu-memory-utilization=0.8 --device=cuda --enforce-eager --served-model-name=$MODEL_NAME
```

## 3.3. Inference Request
Once all the above steps are completed, you can open a new command line interface locally and execute the following command. In the command below, the IP <span style="color:blue;">0.0.0.0</span> and the previously set port number <span style="color:blue;">9999</span> are used to call the inference service in JSON format. The model name field in the model corresponds to the <span style="color:blue;">MODEL_NAME</span> used when starting the inference service.

Continuing with the above settings, the model name is orion14b-chat. The dialogue content is presented in the <span style="color:blue;">content</span> field, and you can also control whether the output is streaming or non-streaming through the <span style="color:blue;">stream</span> field.
```shell
curl http://0.0.0.0:9999/v1/chat/completions -H "Content-Type: application/json" -d '{"model": "orion14b-chat","temperature": 0.2,"stream": false, "messages": [{"role": "user", "content":"Which company developed you as an AI agent?"}]}'
```