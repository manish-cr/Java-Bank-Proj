package com.nexusbank.engine.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.Executor;

@Configuration
public class InterestConfig {

    @Bean
    @ConfigurationProperties(prefix = "app.interest")
    public InterestProperties interestProperties() {
        return new InterestProperties();
    }

    @Bean(name = "interestAccrualExecutor")
    public Executor interestAccrualExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(4);
        executor.setMaxPoolSize(4);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("interest-");
        executor.initialize();
        return executor;
    }

    @Data
    public static class InterestProperties {
        private int threadPoolSize = 4;
        private int batchSize = 25;
    }
}
