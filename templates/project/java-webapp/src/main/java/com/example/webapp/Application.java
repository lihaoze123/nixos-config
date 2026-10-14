package com.example.webapp;

import java.io.File;
import java.nio.file.Files;
import org.apache.catalina.Context;
import org.apache.catalina.startup.Tomcat;
import org.apache.catalina.webresources.JarResourceSet;
import org.apache.catalina.webresources.StandardRoot;

public class Application {
    public static void main(String[] args) throws Exception {
        final Tomcat tomcat = new Tomcat();
        File baseDir = Files.createTempDirectory("java-webapp-").toFile();
        tomcat.setBaseDir(baseDir.getAbsolutePath());
        tomcat.setPort(Integer.parseInt(System.getProperty("server.port", "8080")));
        tomcat.getConnector().setURIEncoding("UTF-8");

        File jar = new File(Application.class.getProtectionDomain().getCodeSource().getLocation().toURI());
        File webapp = new File(baseDir, "webapp");
        Files.createDirectories(webapp.toPath());
        Context context = tomcat.addWebapp("", webapp.getAbsolutePath());
        context.setParentClassLoader(Application.class.getClassLoader());
        // Serve JSP and web.xml directly from the executable JAR.
        StandardRoot resources = new StandardRoot(context);
        resources.addPreResources(new JarResourceSet(resources, "/", jar.getAbsolutePath(), "/webapp"));
        context.setResources(resources);

        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            try {
                tomcat.stop();
                tomcat.destroy();
            } catch (Exception exception) {
                exception.printStackTrace();
            }
        }));
        tomcat.start();
        System.out.println("http://localhost:" + tomcat.getConnector().getLocalPort() + "/");
        tomcat.getServer().await();
    }
}
