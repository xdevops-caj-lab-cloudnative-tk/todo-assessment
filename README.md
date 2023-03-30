# simple To-do List

## Project Overview

A simple web application that allows users to create and manage a list of tasks or to-dos. Users can add, delete, and update tasks, as well as mark tasks as complete.

## Screenshots

1. Simple To-do list

![todo-1](https://user-images.githubusercontent.com/121072143/225633604-7594640b-d3cc-4f7c-9ba8-0f5761b88576.png)

2. Add tasks

![todo-2](https://user-images.githubusercontent.com/121072143/225633588-55e86ef3-a623-4005-a8c5-52bcc356862b.png)

3. Mark task as complete

![todo-3](https://user-images.githubusercontent.com/121072143/225633598-271a6a3d-b879-4666-ac5d-84e66a3878a0.png)

4. Delete task

![todo-4](https://user-images.githubusercontent.com/121072143/225633599-df9bd85f-b69c-486a-8f09-eff9ab2638cc.png)

## 容器化部署

构建应用：

```bash
npm install
npm run build
```

### 使用Red Hat UBI镜像构建

构建镜像：

```bash
podman build -t todo-assessment:1.0.0 .
```

参考文档：
- https://catalog.redhat.com/software/containers/ubi8/nginx-120/6156abfac739c0a4123a86fd?container-tabs=overview


运行容器：

```bash
podman run -d -p 8080:8080 --rm --name todo-assessment todo-assessment:1.0.0 
```

进入容器调试：
```bash
# 进入容器
podman exec -it todo-assessment /bin/bash

# 访问应用
curl localhost:8080

# 当前工作目录为/opt/app-root/src 

# Nginx配置文件为/etc/nginx/nginx.conf
```

在宿主机上访问http://localhost:8080/

### 使用Nginx镜像构建

构建镜像：

```bash
podman build -f Dockerfile.nginx -t todo:1.0.0 .
```

运行容器：

```bash
podman run -d -p 8081:80 --rm --name todo todo:1.0.0 
```

进入容器调试：
```bash
# 进入容器
podman exec -it todo /bin/sh

# 访问应用
curl localhost:80
```
在宿主机上访问http://localhost:8081/

### 推送镜像到Quay

```bash
podman login quay.io
podman tag todo-assessment:1.0.0 quay.io/williamsrlin/todo-assessment:1.0.0
podman push quay.io/williamsrlin/todo-assessment:1.0.0
```

### 部署到Kubernetes

```bash
kubectl apply -f kubernetes/todo-assessment
```
