# 目录

- [🎯 目的](#aim)
- [👄 说明](#intro)
- [👣 使用步骤](#steps)


<a name="aim"></a><br>
# 1. 目的

此工程通过Dockerfile构建基于vLLM推理框架的符合OpenAI接口标准的推理镜像，方便用户启动本地大规模语言模型推理服务。

<a name="intro"></a><br>
# 2. 说明

# 2.1. 推理服务架构
<服务端> --------API调用-------- <客户端>

# 2.2. 推理过程
<客户端>   --------发起推理请求-------->  <服务端>

<客户端>  <--------回复推理请求--------  <服务端>

# 2.3. 详细说明
通常使用大规模语言模型（本文简称LLM）是服务端和客户端的软件架构，中间通过API调用的方式，由客户端发起请求，服务端应答，客户端得到回复。而这其中以OpenAI的API接口最为通用。

OrionStar开发了一个Docker镜像的镜像文件，帮助用户省去软件环境搭建，软件安装，Python安装包安装，服务启动的繁琐步骤，简化整体启动服务过程。对于不了解Docker的用户，请先通过[Docker网站说明链接](https://docs.docker.com/reference/)了解一下，并在本地做好Docker的安装，本文不做赘述。

该镜像基于Ubuntu22.04的系统，Docker构建的步骤包含：

- 安装所有依赖的apt包以及python的PIP包

- 下载vLLM源码，构建并安装vLLM包

- 启动vLLM自带基于OpenAI接口的推理服务

# 2.4. 环境变量
用户需要提前准备好需要推理的模型，并明确以下几个环境变量的含义：

- **MODEL_ABSOLUTE_ROOT**

  模型目录所在的根目录，需要是一个绝对路径，不能是软链接，否则在Docker Container内部无法访问。
该变量主要体现在Docker镜像启动时宿主机模型根路径和容器内模型根路径的映射关系上，即<span style="color:blue;">"-v $MODEL_ABSOLUTE_ROOT:/workspace/models"</span>，这里冒号左边代表宿主机的模型根路径，冒号右边是Docker容器内固定的路径，Docker容器启动会基于/workspace/models结合模型路径正确找到模型。

  举例：假设用户将Orion-14B-Chat模型下载到了<span style="color:blue;">\$HOME/Downloads</span>下，完整的本地模型路径是<span style="color:blue;">\$HOME/Downloads/Orion-14B-Chat</span>，那么MODEL_ABSOLUTE_ROOT就是<span style="color:blue;">\$HOME/Downloads</span>

- **MODEL_DIR**

  模型的目录名。举例：假设用户将Orion-14B-Chat模型下载到了<span style="color:blue;">\$HOME/Downloads</span>下，完整的本地模型路径是<span style="color:blue;">\$HOME/Downloads/Orion-14B-Chat</span>，那么MODEL_DIR就是Orion-14B-Chat

- **MODEL_NAME**

  模型在推理过程中的名字，后续在启动推理请求时需要在HTTP包中注明对应的模型名称，推理请求时，该名称需要保持和推理服务启动时一致的名字

- **CUDA_VISIBLE_DEVICES**

  用户需要确认自己工作环境中的GPU信息，可以通过nvidia-smi确认目前GPU使用情况，自行决定使用几块卡进行推理服务

<a name="steps"></a><br>
# 3. 使用步骤

## 3.1. 构建镜像

该过程最后一步的构建速度取决于网速以及宿主机的性能，中间涉及下载PIP包，可能过程长达20分钟，请耐心等待，如有错误请通过github的issue系统提交错误信息。
此例我们将构建的Docker镜像名称命名为<span style="color:blue;">vllm_server:0.0.0.0</span>
```shell
git clone vllm_server
cd vllm_server
docker build -t vllm_server:0.0.0.0 -f Dockerfile .
```

## 3.2. 启动镜像并开启推理服务
这里宿主机和Docker容器之间的通讯端口使用的是<span style="color:blue;">9999</span>，如果和用户的宿主机服务器有冲突，请自行修改Dockerfile中<span style="color:blue;">ENTRYPOINT</span>部分中，<span style="color:blue;">"--port"</span>的设置，以及docker run启动过程中的宿主机和容器之间的端口映射关系。

这里的<span style="color:blue;">\$MODEL_ABSOLUTE_ROOT</span>按照上面的说明，请填写宿主机的绝对路径，此例我们以下载路径为<span style="color:blue;">\$HOME/Downloads</span>举例
这里我们以主机有两块显卡（0和1，可以通过nvidia-smi命令查看显卡信息）举例<span style="color:blue;">"CUDA_VISIBLE_DEVICES=0，1"</span>，并且容器启动时，会以CUDA的方式运行推理服务。

这里模型目录我们以Orion-14B-Chat为例，并且给与推理服务的模型名为orion14b-chat，通过上一步构建的镜像名称<span style="color:blue;">vllm_server:0.0.0.0</span>启动推理服务
```shell
docker run -it -p 9999:9999 -v $(pwd)/logs:/workspace/logs:rw -v $HOME/Downloads:/workspace/models -e CUDA_VISIBLE_DEVICES=0,1 -e MODEL_DIR=Orion-14B-Chat -e MODEL_NAME=orion14b-chat vllm_server:0.0.0.0
```

## 3.3. 推理请求
上述步骤都完成后，可以在本地新启动一个命令行界面，执行下面的命令，下面的命令中使用了<span style="color:blue;">0.0.0.0</span>的IP以及之前设置的对应端口号<span style="color:blue;">9999</span>，通过json的格式调用推理服务，模型名model字段对应了启动推理服务时使用的<span style="color:blue;">MODEL_NAME</span>。

本例继续接上面的设置orion14b-chat，对话内容呈现在<span style="color:blue;">content</span>字段上，这里也可以通过<span style="color:blue;">stream</span>字段控制流式还是非流式输出。
```shell
curl http://0.0.0.0:9999/v1/chat/completions -H "Content-Type: application/json" -d '{"model": "orion14b-chat","temperature": 0.2,"stream": false, "messages": [{"role": "user", "content":"你是谁开发的"}]}'
```