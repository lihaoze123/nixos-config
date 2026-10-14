<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>Java Webapp</title>
</head>
<body>
    <h1>JSP 运行成功</h1>
    <p>${message}</p>
    <a href="${pageContext.request.contextPath}/hello">Servlet 示例</a>
</body>
</html>
