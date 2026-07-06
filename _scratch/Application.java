// Example: teaching draft for ticket P1-05 — rewrite this line-by-line into
// api/src/main/java/com/healthhub/Application.java, then ask Claude to quiz you.
package com.healthhub;

// Example: @SpringBootApplication is shorthand for three annotations:
//   @Configuration        — this class can declare beans
//   @EnableAutoConfiguration — Spring Boot configures beans based on what's on the classpath
//   @ComponentScan        — scans com.healthhub and below for @Component/@Service/@RestController
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class Application {

    // Example: SpringApplication.run boots the embedded Tomcat server, builds the
    // ApplicationContext (the bean container), and wires all discovered beans together
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}

// Example: quiz topics Claude will ask you about after your rewrite —
//   1. What happens if this class sits in a different package than your controllers?
//   2. Which of the three bundled annotations makes @Service classes discoverable?
//   3. What does Spring Boot auto-configure when it sees spring-boot-starter-data-jpa?
