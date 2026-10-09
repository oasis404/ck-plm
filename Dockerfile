# ===== 阶段 1：构建前端 =====
#产物 frontend/dist 会被拷进后端的 static 目录，最终由 Spring Boot 单体托管，
# 部署时只需一个 jar，不需要额外跑 Node 服务。
FROM node:20-alpine AS frontend

WORKDIR /app/frontend

# 先只拷贝依赖清单，利用 Docker 层缓存：源码变动不会触发npm ci 重跑
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY frontend/ ./
RUN npm run build

# ===== 阶段 2：构建后端 =====
FROM maven:3.9-eclipse-temurin-17 AS backend

WORKDIR /app

#依赖清单先行，最大化复用缓存层
COPY pom.xml ./
RUN mvn -B -q dependency:go-offline

COPY src ./src

# 把前端产物放进 static，Spring Boot 会自动托管为 classpath:/static
COPY --from=frontend /app/frontend/dist ./src/main/resources/static

RUN mvn -B clean package -DskipTests

# ===== 阶段 3：运行环境 =====
FROM eclipse-temurin:17-jre

WORKDIR /app
ENV TZ=Asia/Shanghai \
    JAVA_OPTS="-Xms512m -Xmx1024m -Dfile.encoding=UTF-8"

# temurin 基础镜像不保证带 curl，显式安装，否则下面的 HEALTHCHECK 永远判定失败
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl tzdata \
 && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
 && rm -rf /var/lib/apt/lists/*

COPY --from=backend /app/target/ck-plm-*.jar app.jar

# 上传文件目录需挂卷持久化，否则容器重建后附件丢失
RUN mkdir -p /app/uploads
VOLUME ["/app/uploads"]

EXPOSE 8082

# 用项目真实的 API 端点做探活（项目未实现 /api/health，勿照抄 start.ps1 的写法）
HEALTHCHECK --interval=15s --timeout=5s --start-period=60s --retries=10 \
  CMD curl -fsS http://localhost:8082/v3/api-docs > /dev/null || exit 1

# 用 exec 形式（sh -c 已省掉）保证 java 成为 1 号进程，收到信号才能优雅停机
ENTRYPOINT ["java", \
            "-Djava.security.egd=file:/dev/./urandom", \
            "-jar", "/app/app.jar"]