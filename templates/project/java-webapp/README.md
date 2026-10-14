# Minimal Java Webapp

Temurin JDK 8 + Embedded Tomcat 9.0.123 + javax Servlet 4.0 / JSP 2.3，打包为单个可执行 JAR。

## 初始化与运行

在新目录中初始化 Nix 模板：

```sh
nix flake init -t /home/chumeng/nixos-config#java-webapp
nix develop
mvn clean package
java -jar target/my-jsp-project.jar
```

默认 devShell 使用 Temurin JDK 8，Maven 和 `JAVA_HOME` 均指向它。当前项目已有源码时，使用 Temurin JDK 8 和 Maven 3.6.3+ 执行后两条命令即可。

访问 <http://localhost:8080/> 查看 JSP，访问 <http://localhost:8080/hello> 验证 Servlet 转发至 JSP。Ctrl+C 停止服务。

修改端口：`java -Dserver.port=9090 -jar target/my-jsp-project.jar`。

```text
src/main/java/com/example/webapp/
  Application.java    # 内嵌 Tomcat 启动入口
  HelloServlet.java   # javax Servlet 示例
src/main/webapp/
  index.jsp           # JSP + EL 示例
  WEB-INF/web.xml     # Servlet 注册和首页配置
```

`target/my-jsp-project.jar` 包含 Tomcat、JSP 编译器及 Web 资源，可单独复制到任意目录运行，不依赖源码或外置 Tomcat。Tomcat 的 JSP 编译结果保存在系统临时目录。
