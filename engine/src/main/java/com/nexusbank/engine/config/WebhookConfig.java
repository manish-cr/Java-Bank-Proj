package com.nexusbank.engine.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;

@Configuration
public class WebhookConfig {

    @Bean
    @ConfigurationProperties(prefix = "app.webhook")
    public WebhookProperties webhookProperties() {
        return new WebhookProperties();
    }

    @Bean
    public WebClient webClient() {
        return WebClient.builder().build();
    }

    @Data
    public static class WebhookProperties {
        private String subscriberUrl = "http://localhost:9999/webhook";
        private int maxRetries = 5;
        private long retryDelayMs = 60000;
        private long connectTimeoutMs = 5000;
        private long readTimeoutMs = 10000;
    }
}
