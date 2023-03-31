# 部署VueJS应用到Kubernetes并使用ConfigMap外部化配置

## 构建应用

```bash
npm install
npm run build
```

## 部署到Kubernetes

### VueJS使用环境变量

VueJS支持通过`.env`和`.env.[mode]`方式来定义默认的环境变量和特定模式下的环境变量。

参考文档：
- https://cli.vuejs.org/guide/mode-and-env.html#environment-variables


但是由于运行`npm run build`打包时，webpack会混淆和压缩(minify) 代码，导致无法在运行时从外部注入环境变量。

一种解决方案是对不同模式进行打包，比如开发环境打一个包，测试环境打另一个包，而生产环境再打另一个包。但是这种做法违背了“一次构建，多环境运行"的原则。

### 外部化VueJS配置

下面说明一种实现VueJS应用的“外部化配置”，从而可以使用运行时环境变量或Kubernetes ConfigMap来管理VueJS应用的配置。

#### 定义配置文件

在`src`目录下创建`config.json`文件，内容如下：

```json
{
    "VUE_APP_GREETING": "Hi"
}
```

为什么使用JSON格式的配置文件？因为JSON格式的配置文件可以被VueJS应用直接引入，而且可以使用`jq`命令来替换环境变量。


#### 在VueJS应用中引入配置文件

修改`src/App.vue`文件，引入配置文件：

```html
<template>
  <h1>Hello {{ greeting }}</h1>
</template>

<script>
import Config from "./config.json";

export default {
  data() {
    return {
      newItem: "", //item before adding into array
      items: [], //store items in array
      greeting: Config.VUE_APP_GREETING // inject env variable
    };
  }
}
```

### 多阶段构建容器镜像

#### 多阶段构建的Dockerfile
参见`Dockerfile.multi-stage-rootless`：

```bash
FROM node:14

ENV JQ_VERSION=1.6
RUN wget --no-check-certificate https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 -O /tmp/jq-linux64
RUN cp /tmp/jq-linux64 /usr/bin/jq
RUN chmod +x /usr/bin/jq

WORKDIR /app
COPY . .
RUN jq 'to_entries | map_values({ (.key) : ("$" + .key) }) | reduce .[] as $item ({}; . + $item)' ./src/config.json > ./src/config.tmp.json && mv ./src/config.tmp.json ./src/config.json
RUN npm install && npm run build

FROM nginx:1.17
# VueJS 
ENV JSFOLDER=/opt/app/js/*.js
COPY ./nginx.conf /etc/nginx/nginx.conf
RUN mkdir -p /opt/app && chown -R nginx:nginx /opt/app && chmod -R 775 /opt/app
RUN chown -R nginx:nginx /var/cache/nginx && \
   chown -R nginx:nginx /var/log/nginx && \
   chown -R nginx:nginx /etc/nginx/conf.d
RUN touch /var/run/nginx.pid && \
   chown -R nginx:nginx /var/run/nginx.pid  
RUN chgrp -R root /var/cache/nginx /var/run /var/log/nginx /var/run/nginx.pid && \
   chmod -R 775 /var/cache/nginx /var/run /var/log/nginx /var/run/nginx.pid
COPY ./start-nginx.sh /usr/bin/start-nginx.sh
RUN chmod +x /usr/bin/start-nginx.sh

EXPOSE 8080

WORKDIR /opt/app
# VueJS
COPY --from=0 --chown=nginx /app/dist .
RUN chmod -R a+rw /opt/app
USER nginx
ENTRYPOINT [ "start-nginx.sh" ]
```

说明：
- 第一阶段将使用`node:14`镜像构建应用程序的生产版本。
    - 将所有文件复制到容器中（除了`.docker-ignore`中的文件）。
    - 复制文件，然后运行`​​npm install`来获取项目的依赖项,并运行`npm run build`来打包。
    - 安装了`jq`工具，用于将`src/config.json`中的`value`替换为`$key`。
- 第二阶段`FROM nginx:1.17`，并将第一阶段的文件复制到这个新容器镜像中。
    - 将`nginx.conf`复制到容器中，用于配置Nginx服务器。
    - 将`start-nginx.sh`复制到容器中，用于将VueJS应用打包好后的JavaScript中的环境变量替换为注入的环境变量的值，并启动Nginx服务器。

#### 定义`.docker-ignore`文件

为避免复制不必要的文件，创`.docker-ignore`文件：

```bash
node_modules
```

#### 自动替换`src/config.json`

上述命令`jq 'to_entries | map_values({ (.key) : ("$" + .key) }) | reduce .[] as $item ({}; . + $item)' ./src/config.json`，用于将`src/config.json`中的`value`替换为`$key`。

替换前：
```json
{
    "VUE_APP_GREETING": "Hi"
}
```

替换后：
```json
{
  "VUE_APP_GREETING": "$VUE_APP_GREETING"
}
```


#### 定义`nginx.conf`文件
定义`nginx.conf`文件，说明Nginx使用8080端口以满足rootless容器要求：

```bash
worker_processes auto;
events {
  worker_connections 1024;
}
http {
  include /etc/nginx/mime.types;
  server {
    listen 8080;
    server_name _;
    index index.html;
    location / {
      root /opt/app;
      try_files $uri /index.html;
    }
  }
}
```

#### 定义`start-nginx.sh`文件
定义`start-nginx.sh`文件，用于启动Nginx服务器：

```bash
#!/usr/bin/env bash
export EXISTING_VARS=$(printenv | awk -F= '{print $1}' | sed 's/^/\$/g' | paste -sd,); 
for file in $JSFOLDER;
do
  cat $file | envsubst $EXISTING_VARS > $file.tmp
  mv $file.tmp $file
done
nginx -g 'daemon off;'
```

说明：
- 第一行运行一个命令来获取所有现有环境变量的名称并将它们存储在`$EXISTING_VARS`.
- 然后，此脚本循环遍历生产文件夹中的每个JavaScript文件，并将任何`$VARIABLE`替换为该环境变量的实际值。完成后，它会启动Nginx服务器


#### 构建容器镜像

```bash
podman build -f Dockerfile.multi-stage-rootless -t todo-assessment:1.0.5 .
```

### 运行容器

```bash
podman run -d -p 8080:8080 \
  --rm --name todo-assessment \
  -e VUE_APP_GREETING="Multi Stage Rootless" \
  todo-assessment:1.0.5
```

访问<http://localhost:8080/>，可以看到页面显示`Multi Stage Rootless`。

### 推送到镜像仓库

```bash
podman login quay.io
podman tag todo-assessment:1.0.5 quay.io/williamsrlin/todo-assessment:1.0.5
podman push quay.io/williamsrlin/todo-assessment:1.0.5
```

### 创建Kubernetes ConfigMap

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: todo-assessment-config
data:
  VUE_APP_GREETING: "VueJS applicaiton"
```

后续只需要修改改ConfigMap，并重新部署应用，就可以修改应用的环境变量。

### 在Kuberentes Deployment中使用ConfigMap

```yaml
          env:
            - name: VUE_APP_GREETING
              valueFrom:
                configMapKeyRef:
                  name: todo-assessment-config
                  key: VUE_APP_GREETING
```

### 部署到Kubernetes

```bash
kubectl apply -f kubernetes/todo-assessment
```

完整的YAML在`kubernetes/todo-assessment`目录下。

访问应用，可以看到页面显示`VueJS applicaiton`。

## 使用Kustomize简化多环境部署

### Kustomize目录结构

```bash
todo-assessment
├── base
│   ├── deployment.yaml
│   ├── hpa.yaml
│   ├── kustomization.yaml
│   ├── route.yaml
│   └── service.yaml
└── overlays
    ├── dev
    │   └── kustomization.yaml
    └── test
        └── kustomization.yaml
```

说明
- base目录包含kustomization.yaml文件，该文件定义了所有基础资源的公共部分；并包含所有公共资源的YAML文件。
- overlays目录包含kustomization.yaml文件，包含了动态生成dev和test环境的ConfigMap。

base目录下的kustomization.yaml文件：

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
  - route.yaml
  - hpa.yaml
```

overlays/dev目录下的kustomization.yaml文件：

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

configMapGenerator:
  - name: todo-assessment-config
    literals:
      - VUE_APP_GREETING="VueJS applicaiton on DEV environment"
```

overlays/test目录下的kustomization.yaml文件：

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

configMapGenerator:
  - name: todo-assessment-config
    literals:
      - VUE_APP_GREETING="VueJS applicaiton on TEST environment"
```

完整的YAML在`kubernetes/kustomize-manifest/todo-assessment`目录下。

#### 部署到dev环境

```bash
kubectl apply -k kubernetes/kustomize-manifest/todo-assessment/overlays/dev
```

访问dev环境应用，可以看到页面显示`VueJS applicaiton on DEV environment`。

#### 部署到test环境

```bash
kubectl apply -k kubernetes/kustomize-manifest/todo-assessment/overlays/test
```

访问test环境应用，可以看到页面显示`VueJS applicaiton on TEST environment`。

### 参考文档

- https://github.com/joellord/frontend-containers